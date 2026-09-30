# PATCH LOCAL (fork) - dá suporte à criação de "ticket interno" a partir de
# mensagens selecionadas em outra conversa (ver
# app/javascript/dashboard/components-next/NewConversation/NewInternalTicket.vue).
#
# Copia cada mensagem individualmente (nunca concatena): mantém tipo
# (incoming/outgoing), remetente original (sender_type/sender_id) e os
# anexos (reaproveita o blob do ActiveStorage, sem duplicar o arquivo
# físico). O conteúdo passa por #convert_content antes de gravar - achado
# validado visualmente (screenshot real do Chatwoot): o Message.vue do
# Chatwoot NUNCA interpreta HTML bruto em mensagem content_type "text" (por
# segurança, contra injeção via conteúdo de mensagem) - ele sempre trata
# como markdown/texto puro. Mensagens vindas de ticket do Portal (via
# RichTextEditor caseiro, não é TipTap) guardam HTML de verdade
# (`<p>`, `<strong>`) no campo content; copiar isso sem converter faz as
# tags aparecerem cruas na tela, exatamente o bug relatado. Por isso este
# serviço converte pra markdown antes de copiar, não depois.
#
# `content_attributes.imported_ticket_history` marca a mensagem copiada pro
# frontend renderizar como bloco de histórico de ticket (estilo Movidesk),
# não como bolha de chat normal (ver Message.vue/ImportedHistoryCard.vue) -
# junto guarda os metadados de origem (autor, data/hora e caixa de entrada
# originais) que o card exibe e que não sobreviveriam de outra forma (a
# nova mensagem tem seu próprio created_at, do momento da cópia).
#
# Não usa MessageBuilder/dispatch_create_events na cópia em si (ver loop
# abaixo) - mensagens copiadas passam pelos callbacks normais do Message
# (after_create_commit, reindex etc.), que é o mesmo comportamento de
# qualquer mensagem nova; não há necessidade de suprimir isso.
class Conversations::CopyMessagesService
  Result = Struct.new(:messages, keyword_init: true)

  def initialize(target_conversation:, source_conversation:, message_ids:)
    @target_conversation = target_conversation
    @source_conversation = source_conversation
    @message_ids = message_ids
  end

  def perform
    raise ArgumentError, 'conversa de origem pertence a outra conta' if source_conversation.account_id != target_conversation.account_id

    source_messages = source_conversation.messages.where(id: message_ids).order(:created_at, :id)
    copied = source_messages.map { |original| copy_message(original) }
    Result.new(messages: copied)
  end

  private

  attr_reader :target_conversation, :source_conversation, :message_ids

  def copy_message(original)
    new_message = target_conversation.messages.create!(
      account_id: target_conversation.account_id,
      inbox_id: target_conversation.inbox_id,
      message_type: original.message_type,
      content: convert_content(original.content),
      content_type: original.content_type,
      private: original.private,
      sender_type: original.sender_type,
      sender_id: original.sender_id,
      content_attributes: history_attributes(original)
    )
    copy_attachments(original, new_message)
    new_message
  end

  def history_attributes(original)
    {
      imported_ticket_history: true,
      imported_role: imported_role_for(original),
      original_sender_name: original.sender&.name,
      original_created_at: original.created_at.to_i,
      original_inbox_name: source_conversation.inbox&.name
    }
  end

  def imported_role_for(original)
    return 'internal' if original.private?
    return 'agent' if original.message_type == 'outgoing'

    'customer'
  end

  # Barato pra conteúdo que já é markdown puro (a maioria das mensagens
  # nativas do Chatwoot): só entra no parser quando acha um "<" de verdade.
  # Nokogiri em texto sem tag nenhuma simplesmente devolve o próprio texto -
  # idempotente, seguro rodar em cima de conteúdo que já não tem HTML.
  def convert_content(content)
    return content if content.blank? || content.exclude?('<')

    fragment = Nokogiri::HTML5.fragment(content)
    fragment.css('script, style').remove
    # Cada <div>/<p> vazio (linha em branco deixada no editor de origem) vira
    # "\n\n" próprio - várias seguidas produzem várias quebras em sequência;
    # colapsa pra no máximo uma linha em branco, igual o restante do produto
    # já faz pra conteúdo copiado/sincronizado.
    html_node_to_markdown(fragment).strip.gsub(/\n{3,}/, "\n\n")
  end

  def html_node_to_markdown(node)
    node.children.map { |child| html_child_to_markdown(child) }.join
  end

  def html_child_to_markdown(node)
    case node.name
    when 'text' then node.text
    when 'strong', 'b' then "**#{html_node_to_markdown(node)}**"
    when 'em', 'i' then "*#{html_node_to_markdown(node)}*"
    when 'br' then "\n"
    when 'p', 'div' then "#{html_node_to_markdown(node)}\n\n"
    when 'li' then "- #{html_node_to_markdown(node)}\n"
    else html_node_to_markdown(node)
    end
  end

  def copy_attachments(original, new_message)
    original.attachments.each do |old_attachment|
      new_attachment = new_message.attachments.build(
        account_id: new_message.account_id,
        file_type: old_attachment.file_type,
        external_url: old_attachment.external_url,
        fallback_title: old_attachment.fallback_title,
        extension: old_attachment.extension
      )
      new_attachment.file.attach(old_attachment.file.blob) if old_attachment.file.attached?
    end
    new_message.save! if new_message.attachments.any?
  end
end
