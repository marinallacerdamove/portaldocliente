require 'rails_helper'

RSpec.describe BotFlows::Engine do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:team) { create(:team, account: account) }

  def flow_with_action(action_name, action_params)
    flow = account.bot_flows.new(
      name: 'Fluxo',
      nodes: [{ 'id' => 'start', 'type' => 'start' },
              { 'id' => 'action', 'type' => 'chatwoot_action', 'action_name' => action_name, 'action_params' => action_params }],
      edges: [{ 'source' => 'start', 'target' => 'action', 'sourceHandle' => 'default' }]
    )
    flow.save!(validate: false)
    flow
  end

  describe 'chatwoot_action node' do
    it 'runs an allowed action' do
      described_class.new(conversation).start(flow_with_action('assign_team', [team.id]))

      expect(conversation.reload.team).to eq(team)
    end

    it 'skips an action outside the allowlist of a flow saved before the validation' do
      flow = flow_with_action('instance_eval', 'raise "executed"')

      expect { described_class.new(conversation).start(flow) }.not_to raise_error
    end
  end

  describe 'steps that never pause' do
    it 'stops a cycle between nodes that do not wait for an answer' do
      flow = account.bot_flows.new(
        name: 'Ciclo',
        nodes: [{ 'id' => 'start', 'type' => 'start' },
                { 'id' => 'a', 'type' => 'send_message', 'text' => 'oi' },
                { 'id' => 'b', 'type' => 'send_message', 'text' => 'de novo' }],
        edges: [{ 'source' => 'start', 'target' => 'a', 'sourceHandle' => 'default' },
                { 'source' => 'a', 'target' => 'b', 'sourceHandle' => 'default' },
                { 'source' => 'b', 'target' => 'a', 'sourceHandle' => 'default' }]
      )
      flow.save!

      described_class.new(conversation).start(flow)

      expect(conversation.messages.count).to eq(described_class::MAX_STEPS)
      expect(described_class.new(conversation.reload)).not_to be_running
    end
  end

  describe 'menu waiting for an answer' do
    let(:flow) do
      account.bot_flows.create!(
        name: 'Menu',
        nodes: [{ 'id' => 'start', 'type' => 'start' },
                { 'id' => 'menu', 'type' => 'menu', 'prompt' => 'Escolha', 'options' => [{ 'id' => 'a', 'label' => 'Suporte' }] }],
        edges: [{ 'source' => 'start', 'target' => 'menu', 'sourceHandle' => 'default' }]
      )
    end

    def answer(text)
      message = create(:message, conversation: conversation, account: account, message_type: :incoming, content: text)
      engine = described_class.new(conversation.reload)
      engine.resume(message)
      conversation.reload
    end

    before { described_class.new(conversation).start(flow) }

    it 'shows the menu again twice and then gives up' do
      answer('banana')
      answer('banana')
      expect(described_class.new(conversation)).to be_running
      expect(conversation.messages.where(message_type: :outgoing).count).to eq(3)

      answer('banana')

      expect(described_class.new(conversation)).not_to be_running
      expect(conversation.messages.where(message_type: :outgoing).count).to eq(3)
    end

    it 'forgets a flow that waited longer than the limit' do
      conversation.update!(additional_attributes: conversation.additional_attributes.merge(
        described_class::STATE_STARTED_AT_KEY => (described_class::STATE_TTL + 1.minute).ago.to_i
      ))

      expect(described_class.new(conversation)).not_to be_running
    end

    it 'forgets a flow state saved without a start time' do
      conversation.update!(additional_attributes: conversation.additional_attributes.except(described_class::STATE_STARTED_AT_KEY))

      expect(described_class.new(conversation)).not_to be_running
    end

    it 'is cleared by #stop' do
      expect(described_class.new(conversation)).to be_running

      described_class.new(conversation).stop

      expect(conversation.reload.additional_attributes.keys).not_to include(*described_class::STATE_KEYS)
    end
  end

  # Regressão B35 (auditoria 18/11): o texto do cliente ecoado pelo bot era
  # avaliado como template Liquid (vazava dados de drops e um laço aninhado
  # travava o Sidekiq).
  describe 'customer text echoed by a message' do
    let(:flow) do
      account.bot_flows.create!(
        name: 'Eco',
        nodes: [{ 'id' => 'start', 'type' => 'start' },
                { 'id' => 'ask', 'type' => 'ask_and_extract', 'prompt' => 'Descreva', 'variable_name' => 'detalhes' },
                { 'id' => 'echo', 'type' => 'send_message', 'text' => 'Recebemos: {{detalhes}} ({{ contact.name }}/{{contact.name}})' }],
        edges: [{ 'source' => 'start', 'target' => 'ask', 'sourceHandle' => 'default' },
                { 'source' => 'ask', 'target' => 'echo', 'sourceHandle' => 'default' }]
      )
    end

    it 'keeps the answer literal while still rendering the flow text' do
      conversation.contact.update!(name: 'Ana {{account.name}}')
      described_class.new(conversation).start(flow)
      answer = '{{account.name}} {%for a in (1..3)%}x{%endfor%} {{agent.email}} {'
      message = create(:message, conversation: conversation, account: account, message_type: :incoming, content: answer)

      described_class.new(conversation.reload).resume(message)

      expect(conversation.messages.where(message_type: :outgoing).last.content)
        .to eq("Recebemos: #{answer} (Ana {{account.name}}/Ana {{account.name}})")
    end

    it 'does not let the answer close a raw block' do
      described_class.new(conversation).start(flow)
      answer = '{% raw %}{% endraw %}{{account.name}}'
      message = create(:message, conversation: conversation, account: account, message_type: :incoming, content: answer)

      described_class.new(conversation.reload).resume(message)

      expect(conversation.messages.where(message_type: :outgoing).last.content).to start_with("Recebemos: #{answer} (")
    end
  end
end
