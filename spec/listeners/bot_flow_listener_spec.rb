require 'rails_helper'

describe BotFlowListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox) }
  let(:flow) do
    account.bot_flows.create!(
      name: 'Menu', inbox_ids: [channel.inbox.id],
      nodes: [{ 'id' => 'start', 'type' => 'start' },
              { 'id' => 'menu', 'type' => 'menu', 'prompt' => 'Escolha', 'options' => [{ 'id' => 'a', 'label' => 'Suporte' }] }],
      edges: [{ 'source' => 'start', 'target' => 'menu', 'sourceHandle' => 'default' }]
    )
  end
  let(:message) { create(:message, conversation: conversation, account: account, message_type: :incoming, content: 'banana') }
  let!(:event) { Events::Base.new('message.created', Time.zone.now, message: message) }

  before { BotFlows::Engine.new(conversation).start(flow) }

  def outgoing_count = conversation.messages.where(message_type: :outgoing).count

  it 'keeps the flow going while nobody took over' do
    expect { listener.message_created(event) }.to change { outgoing_count }.by(1)
  end

  it 'does not resume the flow once an agent is assigned' do
    conversation.update!(assignee: create(:user, account: account))

    expect { listener.message_created(event) }.not_to(change { outgoing_count })
    expect(conversation.reload.additional_attributes).not_to have_key(BotFlows::Engine::STATE_NODE_KEY)
  end

  it 'does not resume the flow of a resolved conversation' do
    conversation.update!(status: :resolved)

    expect { listener.message_created(event) }.not_to(change { outgoing_count })
    expect(conversation.reload.additional_attributes).not_to have_key(BotFlows::Engine::STATE_NODE_KEY)
  end
end
