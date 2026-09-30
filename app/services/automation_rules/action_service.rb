class AutomationRules::ActionService < ActionService
  include TicketFieldActions # PATCH LOCAL (fork)

  # PATCH LOCAL (fork) - performed_by: quem fez a mudança que disparou a regra
  # ("Agente logado" dos gatilhos do Movidesk).
  def initialize(rule, account, conversation, performed_by: nil)
    super(conversation)
    @rule = rule
    @account = account
    @user = performed_by if performed_by.is_a?(User)
    Current.executed_by = rule
  end

  def perform
    @rule.actions.each do |action|
      @conversation.reload
      action = action.with_indifferent_access
      begin
        send(action[:action_name], action[:action_params])
      rescue StandardError => e
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
      end
    end
  ensure
    Current.reset
  end

  private

  def send_attachment(blob_ids)
    return if conversation_a_tweet?

    return unless @rule.files.attached?

    blobs = ActiveStorage::Blob.where(id: blob_ids)

    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: "automation_event.#{@rule.event_name}")
    WebhookJob.perform_later(webhook_url[0], payload)
  end

  def send_message(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: false, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def add_private_note(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: true, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation.reload, params).perform
  end

  # PATCH LOCAL (fork) - "self" = quem fez a mudança que disparou a regra.
  def assign_agent(agent_ids = [])
    agent_ids = agent_ids.filter_map { |id| id == 'self' ? @user&.id : id }
    return if agent_ids.empty?

    super(agent_ids)
  end

  # PATCH LOCAL (fork) - "Enviar mensagem" do Movidesk (mensagem interna pra
  # agentes): nota privada mencionando quem precisa saber, o que dispara a
  # notificação do Chatwoot. params: [user_ids, texto]; "creator" = agente
  # que abriu o ticket (primeira mensagem de agente da conversa), "assignee" =
  # responsável atual.
  def notify_agents(params)
    ids, text = params
    ids = Array(ids).filter_map { |id| { 'creator' => ticket_creator_id, 'assignee' => @conversation.assignee_id }.fetch(id, id) }.uniq
    agents = @account.users.where(id: ids)
    return if agents.empty? || text.blank?

    mentions = agents.map { |agent| "[@#{agent.available_name}](mention://user/#{agent.id}/#{ERB::Util.url_encode(agent.available_name)})" }
    params = { content: "#{mentions.join(' ')}\n\n#{render_variables(text)}", private: true,
               content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation.reload, params).perform
  end

  # PATCH LOCAL (fork) - "Criar novo ticket filho" do Movidesk: conversa nova
  # na caixa Tickets Internos, mesmo contato, vinculada como filha (mesmos
  # custom_attributes que o TicketLinkDialog grava) e com a macro aplicada.
  # O "texto da resposta" da macro vira a primeira nota do ticket filho.
  def create_child_ticket(params)
    macro = @account.macros.find_by(id: params[0])
    inbox = @account.inboxes.find_by!(name: 'Tickets Internos')
    contact_inbox = ContactInboxBuilder.new(contact: @conversation.contact, inbox: inbox).perform
    child = ConversationBuilder.new(params: ActionController::Parameters.new({}), contact_inbox: contact_inbox).perform
    link_child_ticket(child)
    return unless macro

    user = @conversation.assignee || @account.administrators.first
    fill_child_description(child, macro, user)
    Macros::ExecutionService.new(macro, child, user).perform
  end

  def link_child_ticket(child)
    child.update!(custom_attributes: child.custom_attributes.merge('ticket_pai_id' => @conversation.display_id.to_s))
    children = @conversation.custom_attributes['ticket_filhos_ids'].to_s.split(',') << child.display_id.to_s
    @conversation.update!(custom_attributes: @conversation.custom_attributes.merge('ticket_filhos_ids' => children.uniq.join(',')))
  end

  def fill_child_description(child, macro, user)
    macro.actions.select { |action| action['action_name'] == 'fill_reply' }.each do |action|
      content = action['action_params'][0]
      Messages::MessageBuilder.new(user, child, { content: content, private: true }).perform if content.present?
    end
  end

  def ticket_creator_id
    @conversation.messages.where(sender_type: 'User').order(:id).pick(:sender_id)
  end

  def send_email_to_team(params)
    teams = Team.where(id: params[0][:team_ids])

    teams.each do |team|
      break unless @account.within_email_rate_limit?

      TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, params[0][:message])&.deliver_now
      @account.increment_email_sent_count
    end
  end
end
