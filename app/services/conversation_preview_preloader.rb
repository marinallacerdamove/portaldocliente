# PATCH LOCAL sobre o upstream Chatwoot - ver docs/patches/conversation_index_n_plus_one.md
#
# Usado por app/views/api/v1/conversations/partials/_conversation.json.jbuilder
# pra eliminar o N+1 de "ultima mensagem" / "ultima mensagem nao-atividade"
# que antes rodava com queries separadas POR conversa (sem preload de
# anexos/remetente). Busca tudo em lote, uma vez por request.
class ConversationPreviewPreloader
  Entry = Struct.new(:last_message, :last_non_activity_message, keyword_init: true)

  def self.preload(conversations)
    new(conversations).perform
  end

  def initialize(conversations)
    @conversations = conversations.to_a
  end

  def perform
    return {} if @conversations.empty?

    last_message_by_conversation_id = fetch_last_message_per_conversation(Message.all)
    last_non_activity_by_conversation_id = fetch_last_message_per_conversation(Message.where.not(message_type: :activity))
    messages_with_associations = fetch_messages_with_associations(last_message_by_conversation_id, last_non_activity_by_conversation_id)

    @conversations.each_with_object({}) do |conversation, hash|
      hash[conversation.id] = Entry.new(
        last_message: resolve(messages_with_associations, last_message_by_conversation_id[conversation.id], conversation),
        last_non_activity_message: resolve(messages_with_associations, last_non_activity_by_conversation_id[conversation.id], conversation)
      )
    end
  end

  private

  def fetch_messages_with_associations(last_message_by_conversation_id, last_non_activity_by_conversation_id)
    message_ids = (last_message_by_conversation_id.values + last_non_activity_by_conversation_id.values).compact.map(&:id).uniq
    Message.where(id: message_ids)
           .includes(:sender, attachments: { file_attachment: :blob })
           .index_by(&:id)
  end

  # DISTINCT ON garante no maximo 1 linha por conversation_id, entao
  # index_by nao tem risco de colisao/sobrescrita silenciosa.
  def fetch_last_message_per_conversation(scope)
    scope.where(conversation_id: conversation_ids, account_id: account_ids)
         .reorder(:conversation_id, created_at: :desc, id: :desc)
         .select('DISTINCT ON (messages.conversation_id) messages.*')
         .index_by(&:conversation_id)
  end

  def resolve(messages_with_associations, bare_message, conversation)
    return nil if bare_message.nil?

    message = messages_with_associations[bare_message.id] || bare_message
    # Reaproveita o objeto de conversa que o finder ja carregou (com
    # contact_inbox/assignee/etc via includes), em vez de deixar
    # message.conversation relancar uma query nova dentro de
    # Message#conversation_push_event_data.
    message.association(:conversation).target = conversation
    message
  end

  def conversation_ids
    @conversation_ids ||= @conversations.map(&:id)
  end

  def account_ids
    @account_ids ||= @conversations.map(&:account_id).uniq
  end
end
