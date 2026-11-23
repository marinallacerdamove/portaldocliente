# Decide QUAL fluxo (BotFlow) disparar - a interpretação do grafo em si
# (nós/arestas) vive em BotFlows::Engine. Só reage a caixas de WhatsApp.
class BotFlowListener < BaseListener
  # PATCH LOCAL: one bot step per conversation at a time (B34). conversation_created and the first
  # message, or two messages together, ran in parallel over the same state; the second waits its turn
  # (the bot may call external APIs, hence the TTL) and then reads the current state.
  BOT_LOCK_TTL = 60.seconds
  BOT_LOCK_WAIT = 0.2

  def conversation_created(event)
    conversation, = extract_conversation_and_account(event)
    return unless whatsapp_conversation?(conversation)

    with_bot_lock(conversation) { start_welcome_flow(conversation.reload) }
  end

  def message_created(event)
    message = event.data[:message]
    return unless message.incoming?

    conversation = message.conversation
    return unless whatsapp_conversation?(conversation)

    with_bot_lock(conversation) { handle_incoming(conversation.reload, message) }
  end

  private

  def with_bot_lock(conversation)
    lock = Redis::LockManager.new
    key = "BOT_FLOW_LOCK::#{conversation.id}"
    deadline = Time.current + BOT_LOCK_TTL
    until lock.lock(key, BOT_LOCK_TTL)
      return Rails.logger.warn("[BotFlowListener] conversation #{conversation.id}: bot busy for too long, skipped") if Time.current > deadline

      sleep BOT_LOCK_WAIT
    end
    begin
      yield
    ensure
      lock.unlock(key)
    end
  end

  def start_welcome_flow(conversation)
    # Conversation an agent opened (assigned or started by an outgoing message): no welcome flow (B79).
    return if human_took_over?(conversation) || agent_started?(conversation)

    engine = BotFlows::Engine.new(conversation)
    return if engine.running?

    flow = matching_flow(conversation, trigger_type: 'conversation_created')
    engine.start(flow) if flow
  end

  def handle_incoming(conversation, message)
    engine = BotFlows::Engine.new(conversation)
    # Agent took over: stop and stay out, no new keyword flow either (B32).
    return engine.stop if human_took_over?(conversation)

    if engine.running?
      engine.resume(message) if after_current_question?(conversation, message)
    else
      flow = matching_flow(conversation, trigger_type: 'keyword', message: message)
      engine.start(flow) if flow
    end
  end

  # Agente atribuído ou conversa resolvida: o bot não retoma o fluxo parado.
  def human_took_over?(conversation)
    conversation.assignee_id.present? || conversation.resolved?
  end

  # A message older than the current question is not its answer (race with conversation_created; B34).
  def after_current_question?(conversation, message)
    started_at = conversation.additional_attributes[BotFlows::Engine::STATE_STARTED_AT_KEY].to_i
    started_at.zero? || message.created_at.to_i >= started_at
  end

  def agent_started?(conversation)
    conversation.messages.outgoing.exists? && !conversation.messages.incoming.exists?
  end

  def whatsapp_conversation?(conversation)
    conversation.present? && conversation.inbox.channel_type == 'Channel::Whatsapp'
  end

  def matching_flow(conversation, trigger_type:, message: nil)
    candidates = conversation.account.bot_flows.active
                             .where(trigger_type: trigger_type)
                             .for_inbox(conversation.inbox_id)
                             .order(:priority, :id)

    return candidates.first if trigger_type == 'conversation_created'

    candidates.detect { |flow| keyword_match?(flow, message) }
  end

  def keyword_match?(flow, message)
    keywords = Array(flow.trigger_config['keywords'])
    content = message.content.to_s.downcase
    keywords.any? { |kw| content.include?(kw.to_s.downcase) }
  end
end
