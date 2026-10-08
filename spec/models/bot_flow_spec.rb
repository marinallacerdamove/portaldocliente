require 'rails_helper'

RSpec.describe BotFlow do
  let(:account) { create(:account) }

  def flow_with_action(action_name)
    described_class.new(
      account: account, name: 'Fluxo',
      nodes: [{ 'id' => 'start', 'type' => 'start' },
              { 'id' => 'action', 'type' => 'chatwoot_action', 'action_name' => action_name, 'action_params' => [] }],
      edges: [{ 'source' => 'start', 'target' => 'action', 'sourceHandle' => 'default' }]
    )
  end

  describe 'CHATWOOT_ACTIONS' do
    it 'matches the list the editor offers (BOT_FLOW_CHATWOOT_ACTIONS)' do
      fixture = JSON.parse(Rails.root.join('spec/fixtures/fork_parity/bot_flow_chatwoot_actions.json').read)
      expect(described_class::CHATWOOT_ACTIONS).to eq(fixture)
    end
  end

  describe 'chatwoot_action node validation' do
    it 'accepts every allowed action' do
      described_class::CHATWOOT_ACTIONS.each do |action_name|
        expect(flow_with_action(action_name)).to be_valid
      end
    end

    it 'rejects an action outside the allowlist' do
      flow = flow_with_action('instance_eval')

      expect(flow).not_to be_valid
      expect(flow.errors[:nodes]).to include("node 1: action 'instance_eval' not supported")
    end
  end
end
