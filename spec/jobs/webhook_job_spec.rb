require 'rails_helper'

RSpec.describe WebhookJob do
  include ActiveJob::TestHelper

  subject(:job) { described_class.perform_later(url, payload, webhook_type) }

  let(:url) { 'https://test.chatwoot.com' }
  let(:payload) { { name: 'test' } }
  let(:webhook_type) { :account_webhook }

  it 'queues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(url, payload, webhook_type)
      .on_queue('medium')
  end

  it 'executes perform with default webhook type' do
    expect(Webhooks::Trigger).to receive(:execute).with(url, payload, webhook_type, secret: nil, delivery_id: nil)
    perform_enqueued_jobs { job }
  end

  context 'with custom webhook type' do
    let(:webhook_type) { :api_inbox_webhook }

    it 'executes perform with inbox webhook type' do
      expect(Webhooks::Trigger).to receive(:execute).with(url, payload, webhook_type, secret: nil, delivery_id: nil)
      perform_enqueued_jobs { job }
    end
  end

  describe 'P0: Portal reliability fix (account_webhook retry)' do
    it 'lets a retryable failure escape #perform unhandled, so Sidekiq applies its own default retry - no custom retry_on needed here' do
      expect(Webhooks::Trigger).to receive(:execute).and_raise(Webhooks::Trigger::RetryableError.new(status: 500,
                                                                                                     message: '500 Internal Server Error'))

      expect { described_class.new.perform(url, payload, :account_webhook) }.to raise_error(Webhooks::Trigger::RetryableError)
    end

    describe 'X-Chatwoot-Delivery across a retry' do
      it 'is generated ONCE, at enqueue time in WebhookListener, not per execution attempt' do
        # WebhookListener#deliver_account_webhooks calls SecureRandom.uuid once per
        # WebhookJob.perform_later - it becomes a literal job argument from then on.
        freeze_time do
          allow(SecureRandom).to receive(:uuid).and_return('fixed-delivery-uuid')

          enqueued = described_class.perform_later(url, payload, :account_webhook, delivery_id: SecureRandom.uuid)

          expect(enqueued.arguments.last[:delivery_id]).to eq('fixed-delivery-uuid')
        end
      end

      it 'is REUSED across a simulated Sidekiq retry - Sidekiq re-executes from the ORIGINAL serialized args' do
        headers_seen = []
        allow(SafeFetch).to receive(:fetch) do |_url, **options, &block|
          headers_seen << options[:headers]['X-Chatwoot-Delivery']
          block.call(instance_double(SafeFetch::Result))
        end

        serialized = described_class.new(url, payload, :account_webhook, delivery_id: 'delivery-abc-123').serialize

        # Sidekiq's retry mechanism re-runs the job from this exact serialized
        # payload (same jid, same args, incremented retry_count) - it does NOT
        # re-invoke WebhookListener, so it can't generate a new UUID either.
        ActiveJob::Base.deserialize(serialized).perform_now # attempt 1 (fails)
        ActiveJob::Base.deserialize(serialized).perform_now # attempt 2 (Sidekiq retry)

        expect(headers_seen).to eq(%w[delivery-abc-123 delivery-abc-123])
      end
    end
  end
end
