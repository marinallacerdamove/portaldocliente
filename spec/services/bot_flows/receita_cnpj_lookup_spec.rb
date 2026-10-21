require 'rails_helper'

RSpec.describe BotFlows::ReceitaCnpjLookup do
  let(:conversation) { create(:conversation) }
  let(:node) { { 'source_variable' => 'resposta' } }
  let(:vars) { { 'resposta' => 'meu cnpj 12.345.678/0001-95' } }
  let(:found_vars) { vars.merge('empresa_razao_social' => 'ACME LTDA', 'empresa_logradouro' => 'Rua A', 'empresa_numero' => '10') }
  let(:caller_double) { instance_double(BotFlows::WebhookCaller) }
  let(:lookup) { described_class.new(node, vars, conversation) }

  before do
    allow(BotFlows::WebhookCaller).to receive(:new).and_return(caller_double)
    allow(lookup).to receive(:sleep)
  end

  it 'does not call the Receita when the answer has no CNPJ' do
    handle, = described_class.new(node, { 'resposta' => 'não sei' }, conversation).call

    expect(handle).to eq('not_found')
    expect(BotFlows::WebhookCaller).not_to have_received(:new)
  end

  it 'asks BrasilAPI with the digits of the CNPJ and answers found with the formatted address' do
    allow(caller_double).to receive(:call).and_return(['success', found_vars])

    handle, result = lookup.call

    expect(handle).to eq('found')
    expect(result['empresa_endereco']).to eq('Rua A, 10')
    expected_url = "#{described_class::BASE_URL}/12345678000195"
    expect(BotFlows::WebhookCaller).to have_received(:new).with(hash_including('url' => expected_url), vars, conversation)
  end

  # Regressão B186: uma falha passageira da BrasilAPI (pública, gratuita, com limite de uso) virava
  # "CNPJ não encontrado" para o time comercial sem nenhuma segunda tentativa
  it 'tries again after a transient failure and answers found when the second attempt works' do
    allow(caller_double).to receive(:call).and_return(['error', vars], ['success', found_vars])

    handle, = lookup.call

    expect(handle).to eq('found')
    expect(caller_double).to have_received(:call).twice
  end

  it 'answers not_found only after every attempt failed' do
    allow(caller_double).to receive(:call).and_return(['error', vars])

    handle, = lookup.call

    expect(handle).to eq('not_found')
    expect(lookup).to have_received(:sleep).with(described_class::RETRY_DELAY_SECONDS).once
    expect(caller_double).to have_received(:call).exactly(described_class::MAX_ATTEMPTS).times
  end

  it 'does not retry nor wait after a success' do
    allow(caller_double).to receive(:call).and_return(['success', found_vars])

    lookup.call

    expect(caller_double).to have_received(:call).once
    expect(lookup).not_to have_received(:sleep)
  end
end
