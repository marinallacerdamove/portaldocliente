require 'rails_helper'

# PATCH LOCAL (fork) - o evento conversation_status_changed levava
# `status_change` (dirty tracking), que no after_commit já é nil: o webhook
# nunca trazia changed_attributes e o Portal não reconhecia o eco da própria
# escrita (auditoria N1). Agora leva status e updated_at do save.
describe Conversation do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account, status: :open) }
  let(:dispatched) { [] }

  before do
    conversation
    allow(Rails.configuration.dispatcher).to receive(:dispatch) { |name, _time, data| dispatched << [name, data] }
  end

  def status_changed_event_data
    dispatched.find { |name, _data| name == described_class::CONVERSATION_STATUS_CHANGED }&.last
  end

  it 'dispatches the status change with status and updated_at' do
    conversation.update!(status: :resolved)

    changed = status_changed_event_data[:changed_attributes]
    expect(changed['status']).to eq(%w[open resolved])
    expect(changed['updated_at'].last).to be_within(0.001).of(conversation.reload.updated_at)
  end

  it 'delivers changed_attributes with updated_at in the conversation_status_changed webhook' do
    webhook = create(:webhook, account: account, subscriptions: %w[conversation_status_changed])
    conversation.update!(status: :pending)
    event = Events::Base.new(described_class::CONVERSATION_STATUS_CHANGED, Time.zone.now, status_changed_event_data)
    delivered = nil
    allow(WebhookJob).to receive(:perform_later) { |url, payload, *| delivered = payload if url == webhook.url }

    WebhookListener.instance.conversation_status_changed(event)

    expect(delivered[:status]).to eq('pending')
    expect(delivered[:changed_attributes]).to include({ 'status' => { previous_value: 'open', current_value: 'pending' } })
    updated_at = delivered[:changed_attributes].find { |change| change.key?('updated_at') }
    expect(updated_at['updated_at'][:current_value]).to be_within(0.001).of(conversation.reload.updated_at)
  end

  it 'keeps the other status events as they were' do
    conversation.update!(status: :resolved)

    resolved = dispatched.find { |name, _data| name == described_class::CONVERSATION_RESOLVED }.last
    expect(resolved[:changed_attributes]).to be_nil
  end
end
