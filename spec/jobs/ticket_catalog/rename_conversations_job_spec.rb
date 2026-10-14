require 'rails_helper'

RSpec.describe TicketCatalog::RenameConversationsJob do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:service) { account.ticket_services.create!(name: 'Fiscal') }

  def conversation_with(attributes, owner = account)
    conversation = create(:conversation, account: owner)
    conversation.update_columns(custom_attributes: attributes) # rubocop:disable Rails/SkipsModelValidations
    conversation
  end

  def attributes_of(conversation) = conversation.reload.custom_attributes

  def rename_without_job(item, name)
    item.update!(name: name)
    clear_enqueued_jobs
  end

  context 'when the item has a code' do
    before do
      service.assign_code('SRV-0001')
      service.save!
    end

    it 'rewrites the name of conversations that carry the code, whatever name they hold' do
      by_code = conversation_with('servico' => 'Nome muito antigo', 'servico_codigo' => 'SRV-0001', 'outro' => 'x')
      other_code = conversation_with('servico' => 'Fiscal', 'servico_codigo' => 'SRV-0002')
      rename_without_job(service, 'Tributário')

      described_class.perform_now(account.id, 'TicketService', [[service.id, 'Fiscal']])

      expect(attributes_of(by_code)).to eq('servico' => 'Tributário', 'servico_codigo' => 'SRV-0001', 'outro' => 'x')
      expect(attributes_of(other_code)).to eq('servico' => 'Fiscal', 'servico_codigo' => 'SRV-0002')
    end

    it 'also catches conversations not backfilled yet by the exact old name' do
      uncoded = conversation_with('servico' => 'Fiscal')
      unrelated = conversation_with('servico' => 'Financeiro')
      rename_without_job(service, 'Tributário')

      described_class.perform_now(account.id, 'TicketService', [[service.id, 'Fiscal']])

      expect(attributes_of(uncoded)).to eq('servico' => 'Tributário')
      expect(attributes_of(unrelated)).to eq('servico' => 'Financeiro')
    end

    it 'leaves the other accounts alone' do
      foreign = conversation_with({ 'servico' => 'Fiscal', 'servico_codigo' => 'SRV-0001' }, other_account)
      rename_without_job(service, 'Tributário')

      described_class.perform_now(account.id, 'TicketService', [[service.id, 'Fiscal']])

      expect(attributes_of(foreign)).to eq('servico' => 'Fiscal', 'servico_codigo' => 'SRV-0001')
    end
  end

  context 'when the item has no code' do
    it 'matches only the exact old name' do
      exact = conversation_with('servico' => 'Fiscal')
      other = conversation_with('servico' => 'Fiscal ')
      coded_elsewhere = conversation_with('servico' => 'Fiscal', 'servico_codigo' => 'SRV-0009')
      rename_without_job(service, 'Tributário')

      described_class.perform_now(account.id, 'TicketService', [[service.id, 'Fiscal']])

      expect(attributes_of(exact)).to eq('servico' => 'Tributário')
      expect(attributes_of(other)).to eq('servico' => 'Fiscal ')
      expect(attributes_of(coded_elsewhere)).to eq('servico' => 'Fiscal', 'servico_codigo' => 'SRV-0009')
    end

    it 'does not steal conversations when another item now holds the old name' do
      rename_without_job(service, 'Tributário')
      newcomer = account.ticket_services.create!(name: 'Fiscal')
      conversation = conversation_with('servico' => 'Fiscal')

      described_class.perform_now(account.id, 'TicketService', [[service.id, 'Fiscal']])

      expect(newcomer.reload.name).to eq('Fiscal')
      expect(attributes_of(conversation)).to eq('servico' => 'Fiscal')
    end
  end

  it 'always writes the current name, so renames in sequence converge in any job order' do
    service.assign_code('SRV-0001')
    service.save!
    coded = conversation_with('servico' => 'Fiscal', 'servico_codigo' => 'SRV-0001')
    uncoded_service = account.ticket_services.create!(name: 'Contábil')
    uncoded = conversation_with('servico' => 'Contábil')
    rename_without_job(service, 'Tributário')
    rename_without_job(service, 'Impostos')
    rename_without_job(uncoded_service, 'Contabilidade')
    rename_without_job(uncoded_service, 'Contabilidade Geral')

    described_class.perform_now(account.id, 'TicketService', [[service.id, 'Tributário']])
    described_class.perform_now(account.id, 'TicketService', [[uncoded_service.id, 'Contabilidade']])
    described_class.perform_now(account.id, 'TicketService', [[service.id, 'Fiscal']])
    described_class.perform_now(account.id, 'TicketService', [[uncoded_service.id, 'Contábil']])
    described_class.perform_now(account.id, 'TicketService', [[uncoded_service.id, 'Contábil']])

    expect(attributes_of(coded)['servico']).to eq('Impostos')
    expect(attributes_of(uncoded)['servico']).to eq('Contabilidade Geral')
  end

  it 'renames the subtree with the full path' do
    parent = account.ticket_services.create!(name: 'Fiscal')
    child = account.ticket_services.create!(name: 'NF-e', parent: parent)
    conversation = conversation_with('servico' => 'Fiscal › NF-e')
    rename_without_job(parent, 'Tributário')

    described_class.perform_now(account.id, 'TicketService', [[parent.id, 'Fiscal'], [child.id, 'Fiscal › NF-e']])

    expect(attributes_of(conversation)).to eq('servico' => 'Tributário › NF-e')
  end

  it 'updates in batches without callbacks or touching updated_at' do
    stub_const("#{described_class}::BATCH_SIZE", 2)
    conversations = Array.new(5) { conversation_with('servico' => 'Fiscal') }
    stamps = conversations.map { |conversation| conversation.reload.updated_at }
    rename_without_job(service, 'Tributário')
    allow(Rails.configuration.dispatcher).to receive(:dispatch)

    described_class.perform_now(account.id, 'TicketService', [[service.id, 'Fiscal']])

    expect(conversations.map { |conversation| attributes_of(conversation)['servico'] }).to all(eq('Tributário'))
    expect(conversations.map { |conversation| conversation.reload.updated_at }).to eq(stamps)
    expect(Rails.configuration.dispatcher).not_to have_received(:dispatch)
  end

  it 'works for every catalog, each with its own key' do
    reason = account.ticket_close_reasons.create!(name: 'Duplicado')
    conversation = conversation_with('motivo_encerramento' => 'Duplicado')
    rename_without_job(reason, 'Duplicidade')

    described_class.perform_now(account.id, 'TicketCloseReason', [[reason.id, 'Duplicado']])

    expect(attributes_of(conversation)).to eq('motivo_encerramento' => 'Duplicidade')
  end

  it 'ignores items that no longer exist and refuses unknown models' do
    expect { described_class.perform_now(account.id, 'TicketService', [[0, 'Fiscal']]) }.not_to raise_error
    expect { described_class.perform_now(account.id, 'User', [[1, 'x']]) }.to raise_error(ArgumentError)
  end
end
