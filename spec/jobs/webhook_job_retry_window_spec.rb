require 'rails_helper'

# Regressão B39 (auditoria 18/11): o webhook de conta para o Portal relançava RetryableError e
# dependia do retry padrão do Sidekiq, que aqui é max_retries 3 (config/sidekiq.yml): ~2 minutos.
# Portal fora por mais que isso (deploy, falta de memória) = resposta, status e resolução feitos no
# Chatwoot nunca chegavam ao Portal. Agora o próprio job tenta de novo por várias horas.
RSpec.describe WebhookJob do
  include ActiveJob::TestHelper

  let(:url) { 'http://portal.test/api/webhooks/chatwoot' }
  let(:payload) { { 'event' => 'message_created' } }
  let(:error) { Webhooks::Trigger::RetryableError.new(status: 503, message: '503 Service Unavailable') }

  before { allow(Webhooks::Trigger).to receive(:execute).and_raise(error) }

  it 'reagenda a entrega para o Portal com o mesmo delivery_id em vez de depender do retry do Sidekiq' do
    job = described_class.new(url, payload, :account_webhook, delivery_id: 'delivery-1')

    expect { job.perform_now }.to have_enqueued_job(described_class)
      .with(url, payload, :account_webhook, delivery_id: 'delivery-1')
  end

  it 'continua tentando até a 11ª execução (janela de várias horas)' do
    job = described_class.new(url, payload, :account_webhook, delivery_id: 'delivery-1')
    job.exception_executions = { '[Webhooks::Trigger::RetryableError]' => 10 }

    expect { job.perform_now }.to have_enqueued_job(described_class)
  end

  it 'a janela somada das esperas passa de 6 horas' do
    job = described_class.new(url, payload, :account_webhook)
    total = (1..(WebhookJob::PORTAL_RETRY_ATTEMPTS - 1)).sum { |n| (n**4) + 2 }

    expect(total).to be > 6.hours.to_i
    expect(job.class::PORTAL_RETRY_ATTEMPTS).to be <= 15
  end

  it 'o webhook do agent bot mantém as 3 tentativas curtas dele' do
    job = AgentBots::WebhookJob.new(url, payload, :agent_bot_webhook)
    job.exception_executions = { '[Webhooks::Trigger::RetryableError]' => 2 }
    allow(Webhooks::Trigger).to receive(:new).and_return(instance_double(Webhooks::Trigger, handle_failure: nil))

    expect { job.perform_now }.not_to have_enqueued_job
  end
end
