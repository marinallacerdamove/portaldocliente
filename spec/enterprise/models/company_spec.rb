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
end
