class WebhookJob < ApplicationJob
  # PATCH LOCAL: the Portal account webhook raises RetryableError when the Portal is down. The
  # Sidekiq default here is max_retries 3 (~2 min), so a Portal restart longer than that lost
  # replies and status changes for good. 12 attempts with polynomial backoff cover ~11 hours;
  # the arguments (and so the delivery_id the Portal deduplicates on) stay the same on every retry.
  # AgentBots::WebhookJob declares its own short retry_on, which takes precedence.
  PORTAL_RETRY_ATTEMPTS = 12
  retry_on Webhooks::Trigger::RetryableError, wait: :polynomially_longer, attempts: PORTAL_RETRY_ATTEMPTS

  queue_as :medium
  #  There are 3 types of webhooks, account, inbox and agent_bot
  def perform(url, payload, webhook_type = :account_webhook, secret: nil, delivery_id: nil)
    Webhooks::Trigger.execute(url, payload, webhook_type, secret: secret, delivery_id: delivery_id)
  end
end
