# PATCH LOCAL (fork) - ações de campo do ticket, comuns a macros e automações
# (gatilhos): assunto com variáveis e "Alterar campo do ticket" (serviço,
# categoria, status, justificativa, campos adicionais...). Quem inclui define
# @account, @conversation e, se houver, @user (quem aplicou).
module TicketFieldActions
  private

  # Mesmo campo que o cabeçalho da conversa mostra (custom_attributes.assunto).
  def set_subject(params) # rubocop:disable Naming/AccessorMethodName -- nome da ação salvo nas macros/automações
    subject = render_variables(params[0]).squish
    return if subject.blank?

    @conversation.update!(custom_attributes: @conversation.custom_attributes.merge('assunto' => subject))
  end

  # [chave do atributo de conversa, valor]
  def set_custom_attribute(params) # rubocop:disable Naming/AccessorMethodName -- nome da ação salvo nas macros/automações
    key, value = params
    return unless @account.custom_attribute_definitions.conversation_attribute.exists?(attribute_key: key)

    @conversation.update!(custom_attributes: @conversation.custom_attributes.merge(key => value))
  end

  def render_variables(text)
    drops = {
      'contact' => ContactDrop.new(@conversation.contact),
      'agent' => UserDrop.new(@user),
      'conversation' => ConversationDrop.new(@conversation),
      'inbox' => InboxDrop.new(@conversation.inbox),
      'account' => AccountDrop.new(@account)
    }.merge(PortalVariables.assigns(@conversation))
    Liquid::Template.parse(text.to_s).render(drops)
  rescue Liquid::Error
    text.to_s
  end
end
