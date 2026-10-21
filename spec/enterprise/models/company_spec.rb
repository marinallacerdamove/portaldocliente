require 'rails_helper'

RSpec.describe Company, type: :model do
  context 'with validations' do
    it { is_expected.to validate_presence_of(:account_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_length_of(:description).is_at_most(1000) }

    describe 'domain validation' do
      it { is_expected.to allow_value('example.com').for(:domain) }
      it { is_expected.to allow_value('sub.example.com').for(:domain) }
      it { is_expected.to allow_value('').for(:domain) }
      it { is_expected.to allow_value(nil).for(:domain) }
      it { is_expected.not_to allow_value('invalid-domain').for(:domain) }
      it { is_expected.not_to allow_value('.example.com').for(:domain) }
    end
  end

  context 'with associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:contacts).dependent(:nullify) }
  end

  describe 'scopes' do
    let(:account) { create(:account) }
    let!(:company_b) { create(:company, name: 'B Company', account: account) }
    let!(:company_a) { create(:company, name: 'A Company', account: account) }
    let!(:company_c) { create(:company, name: 'C Company', account: account) }

    describe '.ordered_by_name' do
      it 'orders companies by name alphabetically' do
        companies = described_class.where(account: account).ordered_by_name
        expect(companies.map(&:name)).to eq([company_a.name, company_b.name, company_c.name])
      end
    end
  end

  describe '#record_activity_at!' do
    it 'does not move company activity backwards' do
      company = create(:company, last_activity_at: Time.zone.now)
      original_activity_at = company.last_activity_at

      company.record_activity_at!(1.hour.ago)

      expect(company.reload.last_activity_at).to be_within(1.second).of(original_activity_at)
    end
  end

  describe 'contact company name sync' do
    let(:account) { create(:account) }
    let(:company) { create(:company, account: account, name: 'Acme') }

    it 'enqueues contact company name sync when the company name changes' do
      expect do
        company.update!(name: 'Acme Labs')
      end.to have_enqueued_job(Companies::SyncContactNamesJob).with(company_id: company.id)
    end
  end

  # PATCH LOCAL (fork) - formato do CPF/CNPJ, só quando muda
  describe 'cnpj format' do
    let(:account) { create(:account) }

    def company_with(cnpj)
      account.companies.new(name: 'ACME', custom_attributes: { 'cnpj' => cnpj })
    end

    it 'accepts a CPF, a numeric CNPJ and an alphanumeric CNPJ, with or without punctuation' do
      ['123.456.789-09', '12.345.678/0001-95', '12.ABC.345/01DE-35', '12abc34501de35'].each do |cnpj|
        expect(company_with(cnpj)).to be_valid, cnpj
      end
    end

    it 'rejects a wrong size or letters in the check digits' do
      ['12345', '12.ABC.345/01DE-3X', '1234567890A'].each do |cnpj|
        company = company_with(cnpj)

        expect(company).not_to be_valid, cnpj
        expect(company.errors[:base].first).to include('CPF')
      end
    end

    it 'accepts a company without CPF/CNPJ' do
      expect(account.companies.new(name: 'Sem documento')).to be_valid
    end

    it 'does not validate again when the CPF/CNPJ did not change' do
      company = account.companies.create!(name: 'Antiga', custom_attributes: { 'cnpj' => '12.345.678/0001-95' })
      company.update_columns(custom_attributes: { 'cnpj' => 'fora do padrao' }) # rubocop:disable Rails/SkipsModelValidations

      expect(company.reload.update(name: 'Antiga Ltda')).to be(true)
      expect(company.update(custom_attributes: { 'cnpj' => 'continua fora' })).to be(false)
    end
  end

  # PATCH LOCAL (fork) - CPF/CNPJ é a chave de ligação com o Portal
  describe 'cnpj uniqueness per account' do
    let(:account) { create(:account) }

    before { account.companies.create!(name: 'ACME', custom_attributes: { 'cnpj' => '12.345.678/0001-95' }) }

    it 'rejects the same key written with other punctuation, in the same account' do
      duplicate = account.companies.new(name: 'Outra', custom_attributes: { 'cnpj' => '12345678000195' })

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:base].first).to include('ACME')
    end

    it 'ignores letter case of an alphanumeric CNPJ' do
      account.companies.create!(name: 'Alfa', custom_attributes: { 'cnpj' => '12.ABC.345/01DE-35' })

      expect(account.companies.new(name: 'Alfa 2', custom_attributes: { 'cnpj' => '12abc34501de35' })).not_to be_valid
    end

    it 'allows the same key in another account' do
      other_account = create(:account)

      expect(other_account.companies.new(name: 'ACME', custom_attributes: { 'cnpj' => '12.345.678/0001-95' })).to be_valid
    end

    it 'lets the company itself be saved again' do
      company = account.companies.find_by(name: 'ACME')

      expect(company.update(description: 'nova descricao')).to be(true)
    end

    it 'allows any number of companies without CPF/CNPJ' do
      account.companies.create!(name: 'Sem 1')

      expect(account.companies.new(name: 'Sem 2')).to be_valid
    end

    # Regressão B189: duas gravações ao mesmo tempo (sync do Portal e agente) passavam as duas pela validação
    # do model e o CPF/CNPJ ficava duplicado na conta; quem barra a corrida é o índice único do banco
    it 'is enforced by the database even when the model validation is skipped' do
      duplicate = account.companies.new(name: 'Corrida', custom_attributes: { 'cnpj' => '12345678000195' })

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique, /index_companies_on_account_id_and_cnpj_key/)
    end

    it 'lets the database accept the same key in another account and companies without CPF/CNPJ' do
      account.companies.new(name: 'Sem 1').save!(validate: false)
      account.companies.new(name: 'Sem 2').save!(validate: false)

      expect { create(:account).companies.new(name: 'ACME', custom_attributes: { 'cnpj' => '12345678000195' }).save!(validate: false) }
        .not_to raise_error
    end
  end

  describe 'Portal sync events' do
    let(:account) { create(:account) }
    let(:dispatcher) { Rails.configuration.dispatcher }

    before { allow(dispatcher).to receive(:dispatch) }

    it 'dispatches company.created on create' do
      company = account.companies.create!(name: 'ACME')

      expect(dispatcher).to have_received(:dispatch).with(Events::Types::COMPANY_CREATED, anything, company: company)
    end

    it 'dispatches company.updated when name or custom attributes change' do
      company = account.companies.create!(name: 'ACME')

      company.update!(name: 'ACME Ltda')
      company.update!(custom_attributes: { 'segmento' => 'varejo' })

      expect(dispatcher).to have_received(:dispatch).with(Events::Types::COMPANY_UPDATED, anything, hash_including(company: company)).twice
    end

    it 'does not dispatch company.updated for attributes the Portal does not mirror' do
      company = account.companies.create!(name: 'ACME')

      company.update!(description: 'texto', domain: 'acme.com', last_activity_at: Time.zone.now)

      expect(dispatcher).not_to have_received(:dispatch).with(Events::Types::COMPANY_UPDATED, anything, anything)
    end
  end

  describe '.sync_empresa_list_attribute!' do
    let(:account) { create(:account) }
    let!(:definition) do
      create(:custom_attribute_definition, account: account, attribute_model: :conversation_attribute,
                                           attribute_key: 'empresa', attribute_display_type: :list, attribute_values: [])
    end

    it 'lists the account companies by name, stripped, unique and sorted' do
      account.companies.create!(name: 'Beta')
      account.companies.create!(name: 'Alfa ')
      account.companies.create!(name: 'Alfa')

      described_class.sync_empresa_list_attribute!(account)

      expect(definition.reload.attribute_values).to eq(%w[Alfa Beta])
    end

    it 'follows company creation, rename and removal on its own' do
      company = account.companies.create!(name: 'Beta')
      expect(definition.reload.attribute_values).to eq(['Beta'])

      company.update!(name: 'Zeta')
      expect(definition.reload.attribute_values).to eq(['Zeta'])

      company.destroy!
      expect(definition.reload.attribute_values).to eq([])
    end

    it 'does nothing when the account has no "empresa" conversation attribute' do
      definition.destroy!
      other = create(:account)
      other.companies.create!(name: 'Alfa')

      expect { described_class.sync_empresa_list_attribute!(other) }.not_to raise_error
    end

    it 'does not touch the list of another account' do
      other = create(:account)
      other.companies.create!(name: 'De outra conta')
      described_class.sync_empresa_list_attribute!(account)

      expect(definition.reload.attribute_values).to eq([])
    end
  end
end
