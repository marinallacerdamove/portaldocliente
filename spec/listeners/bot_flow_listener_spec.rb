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

  # Regressão B32 (auditoria 18/11): com agente atribuído, o bot parava o fluxo mas em seguida
  # procurava fluxo por palavra-chave e começava outro na conversa que o agente atendia.
  it 'does not start a keyword flow in a conversation an agent took over' do
    account.bot_flows.create!(
      name: 'Palavra', inbox_ids: [channel.inbox.id], trigger_type: 'keyword', trigger_config: { 'keywords' => ['banana'] },
      nodes: [{ 'id' => 'start', 'type' => 'start' }, { 'id' => 'msg', 'type' => 'send_message', 'text' => 'Oi do bot' }],
      edges: [{ 'source' => 'start', 'target' => 'msg', 'sourceHandle' => 'default' }]
    )
    conversation.update!(assignee: create(:user, account: account))

    expect { listener.message_created(event) }.not_to(change { outgoing_count })
  end

  # Regressão B79 (auditoria 18/11): o fluxo de conversation_created disparava também na conversa de
  # WhatsApp aberta pelo próprio agente (template ativo), e o bot respondia ao cliente por cima.
  context 'when an agent opens the conversation' do
    let(:fresh) { create(:conversation, account: account, inbox: channel.inbox, assignee: create(:user, account: account)) }

    before do
      account.bot_flows.create!(
        name: 'Boas-vindas', inbox_ids: [channel.inbox.id], trigger_type: 'conversation_created',
        nodes: [{ 'id' => 'start', 'type' => 'start' }, { 'id' => 'msg', 'type' => 'send_message', 'text' => 'Oi do bot' }],
        edges: [{ 'source' => 'start', 'target' => 'msg', 'sourceHandle' => 'default' }]
      )
    end

    it 'does not start the conversation_created flow' do
      listener.conversation_created(Events::Base.new('conversation.created', Time.zone.now, conversation: fresh))

      expect(fresh.reload.messages.where(message_type: :outgoing).count).to eq(0)
    end
  end
end
