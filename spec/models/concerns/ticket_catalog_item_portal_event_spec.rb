require 'rails_helper'

RSpec.describe TicketCatalogItem do
  let(:account) { create(:account) }
  let(:dispatcher) { Rails.configuration.dispatcher }

  before { allow(dispatcher).to receive(:dispatch).and_call_original }

  def expect_dispatch(item, keys)
    expect(dispatcher).to have_received(:dispatch).with(Events::Types::TICKET_CATALOG_UPDATED, anything, item: item, changed_keys: keys).once
  end

  it 'uses the event name the Portal subscribes to' do
    expect(Events::Types::TICKET_CATALOG_UPDATED).to eq('ticket_catalog.updated')
    expect(Webhook::ALLOWED_WEBHOOK_EVENTS).to include('ticket_catalog_updated')
  end

  it 'dispatches the whole contract field list when an item is created' do
    item = account.ticket_close_reasons.create!(name: 'Resolvido')

    expect_dispatch(item, %w[name active position])
  end

  # Regressão B38/B61 (auditoria 18/11): a edição mandava só os campos que mudaram e o Portal descarta
  # a entrega mais velha que a já aplicada: duas edições seguidas entregues invertidas perdiam a
  # primeira (e o push do Portal desfazia a mudança no Chatwoot). Toda entrega leva o item inteiro.
  it 'dispatches the whole contract field list when an item is edited' do
    item = account.ticket_statuses.create!(name: 'Parado', base: 'parado')
    expect(dispatcher).to receive(:dispatch)
      .with(Events::Types::TICKET_CATALOG_UPDATED, anything, item: item, changed_keys: TicketCatalog::SyncFields.fields('status')).once

    item.update!(name: 'Parado 2')
  end

  it 'translates the parent and default type columns to the contract code fields' do
    type = account.ticket_categories.create!(name: 'A')
    root = account.ticket_services.create!(name: 'Financeiro')
    service = account.ticket_services.create!(name: 'Boletos')
    expect(dispatcher).to receive(:dispatch)
      .with(Events::Types::TICKET_CATALOG_UPDATED, anything, item: service, changed_keys: TicketCatalog::SyncFields.fields('servico')).once

    service.update!(parent: root, default_category: type)
  end

  it 'does not dispatch when only a field outside the contract changed' do
    macro = create(:macro, account: account, visibility: :global)
    service = account.ticket_services.create!(name: 'Boletos')
    service.update!(macro: macro)

    expect(dispatcher).to have_received(:dispatch).with(Events::Types::TICKET_CATALOG_UPDATED, any_args).once
  end

  it 'does not dispatch a save without changes' do
    item = account.ticket_close_reasons.create!(name: 'Resolvido')
    item.save!

    expect(dispatcher).to have_received(:dispatch).with(Events::Types::TICKET_CATALOG_UPDATED, anything, any_args).once
  end

  it 'does not dispatch when portal_sync is set (change came from the Portal)' do
    item = account.ticket_close_reasons.new(name: 'Resolvido')
    item.portal_sync = true
    item.save!
    item.update!(name: 'Resolvido 2')

    expect(dispatcher).not_to have_received(:dispatch).with(Events::Types::TICKET_CATALOG_UPDATED, any_args)
  end
end
