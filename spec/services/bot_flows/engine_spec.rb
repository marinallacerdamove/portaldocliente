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
end
