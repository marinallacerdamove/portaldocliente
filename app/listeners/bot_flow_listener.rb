# Decide QUAL fluxo (BotFlow) disparar - a interpretação do grafo em si
# (nós/arestas) vive em BotFlows::Engine. Só reage a caixas de WhatsApp.
class BotFlowListener < BaseListener
  def conversation_created(event)
    conversation, = extract_conversation_and_account(event)
    return unless whatsapp_conversation?(conversation)

    engine = BotFlows::Engine.new(conversation)
    return if engine.running?

    flow = matching_flow(conversation, trigger_type: 'conversation_created')
    engine.start(flow) if flow
  end

  def message_created(event)
    message = event.data[:message]
    return unless message.incoming?

    conversation = message.conversation
    return unless whatsapp_conversation?(conversation)

    engine = BotFlows::Engine.new(conversation)
    if engine.running?
      engine.resume(message)
    else
      flow = matching_flow(conversation, trigger_type: 'keyword', message: message)
      engine.start(flow) if flow
    end
  end

  private

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
