require 'rails_helper'

# Regressão B05 (auditoria 18/11): o construtor de bot grava os cabeçalhos do nó "Chamar webhook"
# como lista de {key, value}; o servidor fazia headers.merge e todo nó desses quebrava com
# NoMethodError, derrubando o EventDispatcherJob. Resposta JSON que não é objeto e conferência de
# sucesso sem campo também quebravam.
RSpec.describe BotFlows::WebhookCaller do
  let(:conversation) { create(:conversation) }
  let(:node) do
    { 'url' => 'https://api.exemplo.com/consulta', 'method' => 'post', 'body_template' => '{"a":1}',
      'headers' => [{ 'key' => 'X-Token', 'value' => 'abc' }, { 'key' => '', 'value' => '' }] }
  end
  let(:result) { instance_double(SafeFetch::Result, tempfile: StringIO.new(response_body)) }
  let(:response_body) { '{"ok":true,"cliente":{"nome":"Ana"}}' }

  before { allow(SafeFetch).to receive(:fetch).and_yield(result) }

  it 'aceita os cabeçalhos no formato da tela (lista de chave e valor), ignorando linha vazia' do
    outcome, = described_class.new(node, {}, conversation).call

    expect(outcome).to eq('success')
    expect(SafeFetch).to have_received(:fetch).with(
      'https://api.exemplo.com/consulta',
      hash_including(headers: { 'X-Token' => 'abc', 'Content-Type' => 'application/json' })
    )
  end

  it 'resposta JSON que não é objeto não quebra o mapeamento' do
    allow(SafeFetch).to receive(:fetch).and_yield(instance_double(SafeFetch::Result, tempfile: StringIO.new('[1,2]')))
    node['response_mappings'] = [{ 'variable_name' => 'nome', 'json_path' => 'cliente.nome' }]

    outcome, vars = described_class.new(node, {}, conversation).call

    expect(outcome).to eq('success')
    expect(vars['nome']).to be_nil
  end

  it 'conferência de sucesso sem campo preenchido é ignorada' do
    node['success_check'] = { 'field' => '', 'equals' => '' }

    outcome, = described_class.new(node, {}, conversation).call

    expect(outcome).to eq('success')
  end

  it 'mapeia campos da resposta' do
    node['response_mappings'] = [{ 'variable_name' => 'nome', 'json_path' => 'cliente.nome' }]

    _, vars = described_class.new(node, {}, conversation).call

    expect(vars['nome']).to eq('Ana')
  end
end
