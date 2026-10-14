require 'rails_helper'

RSpec.describe TicketCatalog::BackfillConversationCodes do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:output) { StringIO.new }
  let!(:coded) { conversation_with('servico' => 'Fiscal', 'motivo_encerramento' => "Cliente d'Ouro") }
  let!(:nested) { conversation_with('servico' => 'Fiscal › NF-e') }
  let!(:uncoded_item) { conversation_with('servico' => 'Sem código') }
  let!(:orphan) { conversation_with('servico' => 'Nome antigo') }
  let!(:foreign) { conversation_with({ 'servico' => 'Fiscal' }, other_account) }

  def conversation_with(attributes, owner = account)
    conversation = create(:conversation, account: owner)
    conversation.update_columns(custom_attributes: attributes) # rubocop:disable Rails/SkipsModelValidations
    conversation
  end

  def attributes_of(conversation) = conversation.reload.custom_attributes

  before do
    conversation_with('servico' => 'Nome antigo')
    fiscal = account.ticket_services.create!(name: 'Fiscal')
    fiscal.assign_code('SRV-0001')
    fiscal.save!
    nfe = account.ticket_services.create!(name: 'NF-e', parent: fiscal)
    nfe.assign_code('SRV-0002')
    nfe.save!
    account.ticket_services.create!(name: 'Sem código')
    reason = account.ticket_close_reasons.create!(name: "Cliente d'Ouro")
    reason.assign_code('MOT-0001')
    reason.save!
  end

  it 'only reports in dry run' do
    result = described_class.new(account.id, output: output).call

    expect(attributes_of(coded)).not_to have_key('servico_codigo')
    expect(result.first).to include(key: 'servico', items_with_code: 2, updated: 2)
    expect(output.string).to include('dry run', '2 conversation(s) would be updated')
  end

  context 'when applying' do
    it 'writes the code next to the matching name, per catalog, in the account only' do
      described_class.new(account.id, apply: true, output: output).call

      expect(attributes_of(coded)).to include('servico_codigo' => 'SRV-0001', 'motivo_encerramento_codigo' => 'MOT-0001')
      expect(attributes_of(nested)).to include('servico_codigo' => 'SRV-0002')
      expect(attributes_of(uncoded_item)).to eq('servico' => 'Sem código')
      expect(attributes_of(orphan)).to eq('servico' => 'Nome antigo')
      expect(attributes_of(foreign)).to eq('servico' => 'Fiscal')
    end

    it 'reports the orphan names per key' do
      result = described_class.new(account.id, apply: true, output: output).call

      expect(result.first[:orphans]).to eq([['Nome antigo', 2]])
      expect(output.string).to include('2 conversation(s) with orphan name (1 distinct)', '2x "Nome antigo"')
    end

    it 'is repeatable and does not touch updated_at' do
      stamp = coded.reload.updated_at
      described_class.new(account.id, apply: true, output: output).call
      second = described_class.new(account.id, apply: true, output: output).call

      expect(second.first[:updated]).to eq(0)
      expect(coded.reload.updated_at).to eq(stamp)
    end

    it 'walks the conversations in id batches' do
      stub_const("#{described_class}::BATCH_SIZE", 1)
      described_class.new(account.id, apply: true, output: output).call

      expect(attributes_of(coded)['servico_codigo']).to eq('SRV-0001')
      expect(attributes_of(nested)['servico_codigo']).to eq('SRV-0002')
    end
  end
end
