# PATCH LOCAL: one bot step (start the welcome flow or answer an incoming message). It runs in its own
# job on the medium queue: the bot may call external APIs (Receita, Portal, webhooks) and wait for the
# per-conversation lock, which used to hold a thread of the critical EventDispatcherJob queue (B82).
class BotFlows::StepJob < ApplicationJob
  queue_as :medium

  def perform(conversation_id, message_id = nil)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    message = message_id && conversation.messages.find_by(id: message_id)
    return if message_id && message.nil?

    BotFlowListener.instance.process_step(conversation, message)
  end
end
