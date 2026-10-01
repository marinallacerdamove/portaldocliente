# PATCH LOCAL (fork) - atividade "Fulano em Checklist X, marcou: ... e
# desmarcou: ..." na conversa, uma por checklist alterado. content_attributes
# .checklist leva os dados pro Portal (WebhookListener manda essa atividade no
# message_created): source "chatwoot" vira histórico lá; "portal" é eco de uma
# marcação que o Portal já registrou. Mesmo texto de TicketChecklistLog.title
# no Portal.
class Conversations::ChecklistActivityService
  def initialize(conversation, before:, actor_name:, source:)
    @conversation = conversation
    @before = before || {}
    @actor_name = actor_name
    @source = source
  end

  def perform
    after = @conversation.custom_attributes&.dig('campos_adicionais') || {}
    TicketCustomField.where(account_id: @conversation.account_id, field_type: 'checklist').find_each do |field|
      marked = Array(after[field.key]) - Array(@before[field.key])
      unmarked = Array(@before[field.key]) - Array(after[field.key])
      next if marked.empty? && unmarked.empty?

      create_activity(field, marked, unmarked)
    end
  end

  private

  def create_activity(field, marked, unmarked)
    @conversation.messages.create!(
      account_id: @conversation.account_id, inbox_id: @conversation.inbox_id, message_type: :activity,
      content: content(field.name, marked, unmarked),
      content_attributes: {
        checklist: { field: field.name, key: field.key, marked: marked, unmarked: unmarked, actor: @actor_name, source: @source }
      }
    )
  end

  def content(field_name, marked, unmarked)
    parts = []
    parts << "marcou: #{marked.join('; ')}" if marked.any?
    parts << "desmarcou: #{unmarked.join('; ')}" if unmarked.any?
    "#{@actor_name} em #{field_name}, #{parts.join(' e ')}"
  end
end
