class Webhooks::Trigger
  SUPPORTED_ERROR_HANDLE_EVENTS = %w[message_created message_updated].freeze
  RETRYABLE_AGENT_BOT_STATUSES = [429, 500].freeze

  # 408 (servidor demorou a receber) e 429/5xx são falha do lado do destino/
  # rede - uma nova tentativa pode dar certo. Escopado só a :account_webhook
  # (o tipo usado por integrações REST genéricas assinando eventos de conta,
  # como o Portal) para não alterar o comportamento de :api_inbox_webhook.
  # Reaproveita a MESMA RetryableError que :agent_bot_webhook já usa, em vez
  # de criar uma classe/pipeline paralelo.
  RETRYABLE_ACCOUNT_WEBHOOK_STATUSES = [408, 429, *(500..599)].freeze

  class RetryableError < StandardError
    attr_reader :status

    def initialize(status:, message:)
      @status = status
      super(message)
    end
  end

  def initialize(url, payload, webhook_type, secret: nil, delivery_id: nil)
    @url = url
    @payload = payload
    @webhook_type = webhook_type
    @secret = secret
    @delivery_id = delivery_id
  end

  def self.execute(url, payload, webhook_type, secret: nil, delivery_id: nil)
    new(url, payload, webhook_type, secret: secret, delivery_id: delivery_id).execute
  end

  def execute
    perform_request
  rescue StandardError => e
    raise RetryableError.new(status: http_status(e), message: e.message) if retryable_agent_bot_error?(e) || retryable_account_webhook_error?(e)

    handle_failure(e)
  end

  # Só chega aqui pra falha que NÃO vira RetryableError (erro definitivo, ou
  # a chamada de handle_failure feita pelo AgentBots::WebhookJob depois de
  # esgotar as tentativas - ver retry_on em app/jobs/agent_bots/webhook_job.rb).
  # Como :account_webhook agora propaga RetryableError direto (sem retry_on
  # próprio - ver comentário em WebhookJob), o Sidekiq já reporta cada
  # tentativa que falha via sentry-sidekiq automaticamente; aqui cobre o
  # caminho que NÃO relança (não tinha nenhum report antes desta mudança).
  def handle_failure(error)
    handle_error(error)
    Rails.logger.warn "Exception: Invalid webhook URL #{@url} : #{error.message}"
    ChatwootExceptionTracker.new(error).capture_exception
  end

  private

  def perform_request
    body = @payload.to_json
    SafeFetch.fetch(
      @url,
      method: :post,
      body: body,
      headers: request_headers(body),
      open_timeout: webhook_timeout,
      read_timeout: webhook_timeout,
      validate_content_type: false
    ) { |_response| nil }
  end

  def request_headers(body)
    headers = { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
    headers['X-Chatwoot-Delivery'] = @delivery_id if @delivery_id.present?
    if @secret.present?
      ts = Time.now.to_i.to_s
      headers['X-Chatwoot-Timestamp'] = ts
      headers['X-Chatwoot-Signature'] = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', @secret, "#{ts}.#{body}")}"
    end
    headers
  end

  def handle_error(error)
    return unless SUPPORTED_ERROR_HANDLE_EVENTS.include?(@payload[:event])
    return unless message

    case @webhook_type
    when :agent_bot_webhook
      update_conversation_status(message)
    when :api_inbox_webhook
      update_message_status(error)
    end
  end

  def update_conversation_status(message)
    conversation = message.conversation
    return unless conversation&.pending?
    return if conversation&.account&.keep_pending_on_bot_failure

    conversation.open!
    create_agent_bot_error_activity(conversation)
  end

  def create_agent_bot_error_activity(conversation)
    content = I18n.t('conversations.activity.agent_bot.error_moved_to_open')
    Conversations::ActivityMessageJob.perform_later(conversation, activity_message_params(conversation, content))
  end

  def activity_message_params(conversation, content)
    {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: content
    }
  end

  def update_message_status(error)
    Messages::StatusUpdateService.new(message, 'failed', error.message).perform
  end

  def message
    return if message_id.blank?

    if defined?(@message)
      @message
    else
      @message = Message.find_by(id: message_id)
    end
  end

  def message_id
    @payload[:id]
  end

  def webhook_timeout
    raw_timeout = GlobalConfig.get_value('WEBHOOK_TIMEOUT')
    timeout = raw_timeout.presence&.to_i

    timeout&.positive? ? timeout : 5
  end

  def retryable_agent_bot_error?(error)
    @webhook_type == :agent_bot_webhook && RETRYABLE_AGENT_BOT_STATUSES.include?(http_status(error))
  end

  # SafeFetch::FetchError (timeout, conexão recusada, DNS etc. - ver
  # lib/safe_fetch/fetcher.rb) não carrega status HTTP nenhum: é sempre uma
  # falha de rede/servidor, sempre retryable pra este tipo. SafeFetch::HttpError
  # só é retryable nos status acima - um 4xx (URL/payload rejeitados pelo
  # destino) não é, repetir o mesmo corpo falha de novo.
  def retryable_account_webhook_error?(error)
    return false unless @webhook_type == :account_webhook

    error.is_a?(SafeFetch::FetchError) || RETRYABLE_ACCOUNT_WEBHOOK_STATUSES.include?(http_status(error))
  end

  def http_status(error)
    return unless error.is_a?(SafeFetch::HttpError)

    error.message.to_s[/\A(\d{3})\b/, 1]&.to_i
  end
end
