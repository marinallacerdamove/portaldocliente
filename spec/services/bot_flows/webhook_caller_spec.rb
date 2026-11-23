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

  # Regressão B83 (auditoria 18/11): a resposta do cliente entrava crua no corpo JSON do webhook.
  # Aspas no texto fechavam o campo e injetavam outros ("admin": true...) ou quebravam o JSON.
  it 'escapa o texto do cliente dentro do corpo JSON' do
    node['body_template'] = '{"nome":"{{nome}}"}'
    described_class.new(node, { 'nome' => 'Ana", "admin": true, "x": "' }, conversation).call

    expect(SafeFetch).to have_received(:fetch) do |_url, **options|
      expect(JSON.parse(options[:body])).to eq('nome' => 'Ana", "admin": true, "x": "')
    end
  end

  # Regressão B84 (auditoria 18/11): a tela grava o valor esperado como texto ("true", "1"), e a resposta
  # JSON traz booleano/número: a conferência nunca batia e o fluxo seguia sempre pelo caminho de erro.
  it 'compara o valor esperado como texto com booleano e número da resposta' do
    allow(SafeFetch).to receive(:fetch) do |*_args, **_options, &block|
      block.call(instance_double(SafeFetch::Result, tempfile: StringIO.new('{"found":true,"total":2}')))
    end
    node['success_check'] = { 'field' => 'found', 'equals' => 'true' }

    outcome, = described_class.new(node, {}, conversation).call
    expect(outcome).to eq('success')

    node['success_check'] = { 'field' => 'total', 'equals' => '2' }
    outcome, = described_class.new(node, {}, conversation).call
    expect(outcome).to eq('success')
  end
end
