# Fluxo de boas-vindas do WhatsApp (só pra esse canal - não mexe em Portal do
# Cliente/Tickets Internos): ao abrir uma conversa nova, manda um menu
# clicável (lista interativa do WhatsApp) pra escolher o setor; a escolha
# direciona a conversa pro time certo e pede descrição/empresa/CNPJ em
# seguida. O estado do fluxo fica em additional_attributes (não é um dado
# pra aparecer pro agente, por isso não é custom_attributes).
#
# As opções do menu vêm do atributo personalizado "setor" (Configurações >
# Atributos personalizados) e o direcionamento usa o nome do time (Equipes)
# que bater com o texto escolhido - de propósito, pra dar pra ajustar setor
# e equipe de destino direto pela tela do Chatwoot, sem precisar mexer
# nesse código pra cada mudança.
class WhatsappSetorMenuListener < BaseListener
  SETOR_ATTRIBUTE_KEY = 'setor'.freeze

  MENU_PROMPT = 'Olá! Selecione o setor desejado para o seu atendimento:'.freeze
  RETRY_PROMPT = 'Não entendi sua escolha. Por favor, selecione uma das opções abaixo:'.freeze
  DETAILS_PROMPT = 'Por favor, descreva a situação, o nome da empresa e o CNPJ para prosseguirmos com o atendimento.'.freeze
  KNOWN_COMPANY_REPLY = 'Olá, %<contact_name>s! Vi que sua empresa é a %<empresa_nome>s. Como podemos te ajudar?'.freeze
  UNKNOWN_COMPANY_REPLY = 'Olá, %<contact_name>s! Recebemos sua solicitação, em breve um atendente vai te responder.'.freeze
  STEP_KEY = 'setor_flow_step'.freeze
  CNPJ_REGEX = /\d{2}\.?\d{3}\.?\d{3}\/?\d{4}-?\d{2}/.freeze

  def conversation_created(event)
    conversation, = extract_conversation_and_account(event)
    return unless whatsapp_conversation?(conversation)
    return if conversation.additional_attributes[STEP_KEY].present?

    setores = setores_for(conversation.account)
    return if setores.empty?

    send_setor_menu(conversation, MENU_PROMPT, setores)
    set_step(conversation, 'awaiting_setor')
  end

  def message_created(event)
    message = event.data[:message]
    return unless message.incoming?

    conversation = message.conversation
    return unless whatsapp_conversation?(conversation)

    case conversation.additional_attributes[STEP_KEY]
    when 'awaiting_setor'
      handle_setor_reply(conversation, message)
    when 'awaiting_details'
      handle_details_reply(conversation, message)
    end
  end

  private

  def whatsapp_conversation?(conversation)
    conversation.present? && conversation.inbox.channel_type == 'Channel::Whatsapp'
  end

  def setores_for(account)
    definition = account.custom_attribute_definitions.find_by(attribute_key: SETOR_ATTRIBUTE_KEY, attribute_model: 'conversation_attribute')
    definition&.attribute_values || []
  end

  def team_for_setor(account, title)
    account.teams.detect { |team| team.name.downcase == title.downcase }
  end

  def set_step(conversation, step)
    conversation.update!(additional_attributes: conversation.additional_attributes.merge(STEP_KEY => step))
  end

  def send_setor_menu(conversation, prompt, setores)
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: prompt,
      content_type: :input_select,
      content_attributes: {
        'items' => setores.map { |title| { 'title' => title, 'value' => title.parameterize } }
      }
    )
  end

  def handle_setor_reply(conversation, message)
    setores = setores_for(conversation.account)
    chosen = setores.detect { |title| title.downcase == message.content.to_s.strip.downcase }
    unless chosen
      send_setor_menu(conversation, RETRY_PROMPT, setores)
      return
    end

    team = team_for_setor(conversation.account, chosen)
    conversation.update!(team: team) if team

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: DETAILS_PROMPT
    )
    set_step(conversation, 'awaiting_details')
  end

  def handle_details_reply(conversation, message)
    cnpj = message.content.to_s[CNPJ_REGEX]
    empresa = cnpj.present? ? lookup_empresa_by_cnpj(cnpj) : nil
    contact_name = conversation.contact.name.presence || 'tudo bem'

    content = if empresa
      format(KNOWN_COMPANY_REPLY, contact_name: contact_name, empresa_nome: empresa['nome'])
    else
      format(UNKNOWN_COMPANY_REPLY, contact_name: contact_name)
    end

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: content
    )
    set_step(conversation, 'completed')
  end

  # Busca no Portal do Cliente (banco separado do Chatwoot) se o CNPJ
  # informado já é de uma empresa cadastrada - autenticado por token
  # compartilhado, ver Api::InternalController no backend do Portal.
  def lookup_empresa_by_cnpj(cnpj)
    base_url = ENV.fetch('PORTAL_INTERNAL_API_URL', nil)
    token = ENV.fetch('PORTAL_INTERNAL_API_TOKEN', nil)
    return nil if base_url.blank? || token.blank?

    response = HTTParty.get(
      "#{base_url}/api/internal/empresa_by_cnpj",
      query: { cnpj: cnpj },
      headers: { 'X-Internal-Token' => token },
      timeout: 5
    )
    return nil unless response.success?

    data = response.parsed_response
    data['found'] ? data : nil
  rescue StandardError => e
    Rails.logger.error("[WhatsappSetorMenuListener] erro ao buscar empresa por CNPJ: #{e.message}")
    nil
  end
end
