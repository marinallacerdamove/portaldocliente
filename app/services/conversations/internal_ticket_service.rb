# PATCH LOCAL (fork) - cria um ticket (conversa nova) com tudo o que o
# formulário define, numa transação só: time, responsável, prioridade,
# custom_attributes, primeira mensagem (com anexos), mensagens copiadas de
# outra conversa, agentes em cópia e o vínculo pai/filho com uma conversa
# existente. Falhou um passo, nada fica gravado: o agente tenta de novo sem
# duplicar o ticket. A automação de criação já vê o ticket completo.
# Usado pelo "Novo ticket interno" e pelo ticket pai/filho novo
# (Api::V1::Accounts::InternalTicketsController) e pelo gatilho "Criar novo
# ticket filho" (AutomationRules::ActionService).
#
# params (todas opcionais): team, assignee, priority, custom_attributes,
# message: { content:, private:, attachments: }, copy: { source:, message_ids: },
# watcher_ids, link: { conversation:, relation: 'parent'|'child', announce: },
# em que relation é o papel do ticket novo em relação a link[:conversation] e
# announce deixa uma nota privada nela apontando pro ticket novo.
class Conversations::InternalTicketService
  class InvalidTicket < StandardError; end

  RELATION_LABELS = { 'parent' => 'pai', 'child' => 'filho' }.freeze

  def initialize(inbox:, contact:, user:, params: {})
    @inbox = inbox
    @contact = contact
    @user = user
    @params = params
  end

  def perform
    validate!
    ActiveRecord::Base.transaction do
      @conversation = create_conversation
      create_first_message
      copy_messages
      add_watchers
      link_conversation
      @conversation.reload
    end
  end

  private

  def validate!
    raise InvalidTicket, 'priority' if @params[:priority].present? && !Conversation.priorities.key?(@params[:priority].to_s)
    raise InvalidTicket, 'relation' if link.present? && RELATION_LABELS.keys.exclude?(link[:relation].to_s)
    raise InvalidTicket, 'watchers' if (watcher_ids - @inbox.assignable_agents.map(&:id)).any?
  end

  def create_conversation
    contact_inbox = ContactInboxBuilder.new(contact: @contact, inbox: @inbox).perform
    conversation = Conversation.create!(
      account_id: @inbox.account_id, inbox_id: @inbox.id, contact_id: @contact.id, contact_inbox_id: contact_inbox.id,
      team: @params[:team], assignee: @params[:assignee], priority: @params[:priority].presence,
      custom_attributes: (@params[:custom_attributes] || {}).to_h
    )
    conversation.reload
  end

  def create_first_message
    message = @params[:message]
    return if message.blank? || (message[:content].blank? && message[:attachments].blank?)

    Messages::MessageBuilder.new(@user, @conversation, message).perform
  end

  def copy_messages
    copy = @params[:copy]
    return if copy.blank? || copy[:message_ids].blank?

    Conversations::CopyMessagesService.new(
      target_conversation: @conversation, source_conversation: copy[:source], message_ids: copy[:message_ids]
    ).perform
  end

  def add_watchers
    watcher_ids.each { |user_id| @conversation.conversation_participants.find_or_create_by!(user_id: user_id) }
  end

  def link_conversation
    return if link.blank?

    related = link[:conversation]
    parent, child = link[:relation].to_s == 'parent' ? [@conversation, related] : [related, @conversation]
    Conversations::TicketLinkService.new(parent: parent, child: child).perform
    announce(related) if link[:announce]
  end

  def announce(related)
    team = @conversation.team ? " para o time #{@conversation.team.name}" : ''
    url = Rails.application.routes.url_helpers.app_account_conversation_url(account_id: @conversation.account_id, id: @conversation.display_id)
    content = "Ticket #{RELATION_LABELS[link[:relation].to_s]} criado#{team}: #{url}"
    Messages::MessageBuilder.new(@user, related, { content: content, private: true }).perform
  end

  def link
    @params[:link]
  end

  def watcher_ids
    Array(@params[:watcher_ids]).map(&:to_i).uniq
  end
end
