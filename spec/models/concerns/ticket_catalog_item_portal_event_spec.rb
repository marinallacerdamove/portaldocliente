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

  it 'dispatches only the synced fields that changed' do
    item = account.ticket_statuses.create!(name: 'Parado', base: 'parado')
    item.update!(name: 'Parado 2', requires_justification: true)

    expect_dispatch(item, %w[name requires_justification])
  end

  it 'translates the parent and default type columns to the contract code fields' do
    type = account.ticket_categories.create!(name: 'A')
    root = account.ticket_services.create!(name: 'Financeiro')
    service = account.ticket_services.create!(name: 'Boletos')
    service.update!(parent: root, default_category: type)

    expect_dispatch(service, %w[parent_code default_category_code])
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
