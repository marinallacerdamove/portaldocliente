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

  # Regressão B80 (auditoria 18/11): o menu aceitava rótulos e quantidade de opções acima do limite do
  # WhatsApp (botões: até 3, título até 20; lista: até 10, título até 24). A mensagem era recusada e o
  # fluxo ficava parado esperando uma resposta que não vinha.
  describe 'menu dentro dos limites do WhatsApp' do
    def menu_flow(labels)
      described_class.new(
        account: account, name: 'Menu',
        nodes: [{ 'id' => 'start', 'type' => 'start' },
                { 'id' => 'menu', 'type' => 'menu', 'prompt' => 'Escolha',
                  'options' => labels.each_with_index.map { |label, i| { 'id' => "o#{i}", 'label' => label } } }],
        edges: [{ 'source' => 'start', 'target' => 'menu', 'sourceHandle' => 'default' }]
      )
    end

    it 'recusa botão (até 3 opções) com mais de 20 caracteres' do
      expect(menu_flow(['a' * 21, 'b']).valid?).to be(false)
    end

    it 'recusa lista com mais de 10 opções ou rótulo com mais de 24 caracteres' do
      expect(menu_flow((1..11).map { |i| "Opção #{i}" }).valid?).to be(false)
      expect(menu_flow(['a' * 25, 'b', 'c', 'd']).valid?).to be(false)
    end

    it 'aceita menu dentro dos limites' do
      expect(menu_flow(['a' * 20, 'b']).valid?).to be(true)
      expect(menu_flow(['a' * 24, 'b', 'c', 'd']).valid?).to be(true)
    end
  end
end
