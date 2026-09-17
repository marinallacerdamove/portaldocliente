# Fluxo de boas-vindas do WhatsApp (só pra esse canal - não mexe em Portal do
# Cliente/Tickets Internos): ao abrir uma conversa nova, manda um menu
# clicável (lista interativa do WhatsApp) pra escolher o setor; a escolha
# direciona a conversa pro time certo e pede descrição/empresa/CNPJ em
# seguida. O estado do fluxo fica em additional_attributes (não é um dado
# pra aparecer pro agente, por isso não é custom_attributes).
class WhatsappSetorMenuListener < BaseListener
  SETORES = {
    'Suporte Técnico' => 'suporte técnico',
    'Financeiro' => 'financeiro',
    'Comercial' => 'comercial',
    'Implantação' => 'implantação'
  }.freeze

  MENU_PROMPT = 'Olá! Selecione o setor desejado para o seu atendimento:'.freeze
  RETRY_PROMPT = 'Não entendi sua escolha. Por favor, selecione uma das opções abaixo:'.freeze
  DETAILS_PROMPT = 'Por favor, descreva a situação, o nome da empresa e o CNPJ para prosseguirmos com o atendimento.'.freeze
  STEP_KEY = 'setor_flow_step'.freeze

  def conversation_created(event)
    conversation, = extract_conversation_and_account(event)
    return unless whatsapp_conversation?(conversation)
    return if conversation.additional_attributes[STEP_KEY].present?

    send_setor_menu(conversation, MENU_PROMPT)
    set_step(conversation, 'awaiting_setor')
  end

  def message_created(event)
    message = event.data[:message]
    return unless message.incoming?

    conversation = message.conversation
    return unless whatsapp_conversation?(conversation)
    return unless conversation.additional_attributes[STEP_KEY] == 'awaiting_setor'

    handle_setor_reply(conversation, message)
  end

  private

  def whatsapp_conversation?(conversation)
    conversation.present? && conversation.inbox.channel_type == 'Channel::Whatsapp'
  end

  def set_step(conversation, step)
    conversation.update!(additional_attributes: conversation.additional_attributes.merge(STEP_KEY => step))
  end

  def send_setor_menu(conversation, prompt)
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: prompt,
      content_type: :input_select,
      content_attributes: {
        'items' => SETORES.keys.map { |title| { 'title' => title, 'value' => title.parameterize } }
      }
    )
  end

  def handle_setor_reply(conversation, message)
    team_name = SETORES[message.content.to_s.strip]
    unless team_name
      send_setor_menu(conversation, RETRY_PROMPT)
      return
    end

    team = conversation.account.teams.find_by(name: team_name)
    conversation.update!(team: team) if team

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: DETAILS_PROMPT
    )
    set_step(conversation, 'awaiting_details')
  end
end
