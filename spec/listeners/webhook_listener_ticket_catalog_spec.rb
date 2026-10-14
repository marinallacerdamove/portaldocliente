require 'rails_helper'

describe WebhookListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:item) { account.ticket_close_reasons.create!(name: 'Resolvido') }
  let(:event) { Events::Base.new('ticket_catalog.updated', Time.zone.now, item: item, changed_keys: %w[name]) }

  it 'delivers nothing when no webhook subscribes to the event' do
    create(:webhook, account: account, subscriptions: %w[conversation_created])
    expect(WebhookJob).not_to receive(:perform_later)

    listener.ticket_catalog_updated(event)
  end

  it 'delivers nothing when the account has no webhook at all' do
    expect(WebhookJob).not_to receive(:perform_later)

    listener.ticket_catalog_updated(event)
  end

  it 'delivers the catalog payload to the account webhooks that subscribe' do
    webhook = create(:webhook, account: account, subscriptions: %w[ticket_catalog_updated])
    expected = TicketCatalog::WebhookPayload.new(item, %w[name]).as_json

    expect(WebhookJob).to receive(:perform_later)
      .with(webhook.url, expected, :account_webhook, secret: webhook.secret, delivery_id: instance_of(String)).once

    listener.ticket_catalog_updated(event)
  end

  it 'can be subscribed through the webhook model' do
    webhook = build(:webhook, account: account, subscriptions: %w[ticket_catalog_updated])

    expect(webhook).to be_valid
  end
end
