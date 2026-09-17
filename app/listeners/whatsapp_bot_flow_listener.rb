# Motor genérico do fluxo de boas-vindas do WhatsApp (só pra esse canal -
# não mexe em Portal do Cliente/Tickets Internos). A SEQUÊNCIA de passos
# fica em Inbox#bot_flow_steps (editável em Configurações > Caixas de
# Entrada > [caixa de WhatsApp] > aba "Fluxo de Boas-vindas", sem precisar
# de deploy); este listener só INTERPRETA essa sequência - não conhece
# nenhum passo específico (nem "setor"), só os 3 tipos suportados.
#
# Tipos de passo (bot_flow_steps, array de hashes):
#   - "menu": manda uma lista clicável com os valores de um Atributo
#     Personalizado (attribute_key); a escolha direciona a conversa pro
#     Time (Equipes) com o mesmo nome.
#   - "ask_and_extract": pergunta algo em texto livre; opcionalmente
#     (extract: "cnpj") tenta achar um CNPJ na resposta e busca no Portal,
#     respondendo com found_canned_response/not_found_canned_response.
#   - "message": só manda uma Resposta Pronta e segue pro próximo passo
#     sozinho (não espera resposta) - útil pra avisos entre passos.
#
# Textos vêm de Respostas Prontas pelo short_code configurado em cada
# passo - se a resposta pronta não existir, usa um texto padrão genérico.
#
# O passo atual de cada conversa fica em
# additional_attributes['bot_flow_step_index'] (não é dado pra aparecer
# pro agente, por isso não é custom_attributes): nil = fluxo não começou,
# um índice = esperando resposta daquele passo, -1 = fluxo concluído.
class WhatsappBotFlowListener < BaseListener
  STEP_INDEX_KEY = 'bot_flow_step_index'.freeze
  CNPJ_REGEX = /\d{2}\.?\d{3}\.?\d{3}\/?\d{4}-?\d{2}/.freeze
  DEFAULT_MENU_PROMPT = 'Selecione uma opção:'.freeze
  DEFAULT_RETRY_PROMPT = 'Não entendi sua escolha. Por favor, selecione uma das opções abaixo:'.freeze
  DEFAULT_ASK_PROMPT = 'Por favor, nos conte mais.'.freeze
  DEFAULT_KNOWN_COMPANY_REPLY = 'Olá, %<contact_name>s! Vi que sua empresa é a %<empresa_nome>s. Como podemos te ajudar?'.freeze
  DEFAULT_UNKNOWN_COMPANY_REPLY = 'Olá, %<contact_name>s! Recebemos sua solicitação, em breve um atendente vai te responder.'.freeze

  def conversation_created(event)
    conversation, = extract_conversation_and_account(event)
    return unless whatsapp_conversation?(conversation)
    return if conversation.additional_attributes[STEP_INDEX_KEY].present?
    return if bot_flow_steps(conversation).blank?

    run_from(conversation, 0)
  end

  def message_created(event)
    message = event.data[:message]
    return unless message.incoming?

    conversation = message.conversation
    return unless whatsapp_conversation?(conversation)

    steps = bot_flow_steps(conversation)
    index = conversation.additional_attributes[STEP_INDEX_KEY]
    return if index.blank? || index == -1

    step = steps[index]
    return if step.blank?

    advance = handle_reply(conversation, message, step)
    run_from(conversation, index + 1) if advance
  end

  private

  def whatsapp_conversation?(conversation)
    conversation.present? && conversation.inbox.channel_type == 'Channel::Whatsapp'
  end

  def bot_flow_steps(conversation)
    conversation.inbox.bot_flow_steps || []
  end

  # Executa passos a partir de `index`, atravessando automaticamente
  # qualquer sequência de passos "message" (não esperam resposta) até
  # achar um passo que espera entrada, ou até acabar o array.
  def run_from(conversation, index)
    steps = bot_flow_steps(conversation)

    loop do
      if index >= steps.length
        set_step_index(conversation, -1)
        return
      end

      step = steps[index]
      case step['type']
      when 'menu'
        send_menu(conversation, step)
        set_step_index(conversation, index)
        return
      when 'ask_and_extract'
        send_bot_message(conversation, canned_text(conversation.account, step['prompt_canned_response'], DEFAULT_ASK_PROMPT))
        set_step_index(conversation, index)
        return
      when 'message'
        send_bot_message(conversation, canned_text(conversation.account, step['canned_response'], ''))
        index += 1
      else
        Rails.logger.error("[WhatsappBotFlowListener] passo #{index} com tipo desconhecido '#{step['type']}', pulando")
        index += 1
      end
    end
  end

  # Retorna true se o fluxo deve avançar pro próximo passo (false mantém a
  # conversa esperando uma resposta válida no mesmo passo, ex.: menu com
  # opção não reconhecida).
  def handle_reply(conversation, message, step)
    case step['type']
    when 'menu'
      handle_menu_reply(conversation, message, step)
    when 'ask_and_extract'
      handle_ask_and_extract_reply(conversation, message, step)
      true
    else
      true
    end
  end

  def handle_menu_reply(conversation, message, step)
    account = conversation.account
    options = attribute_values_for(account, step['attribute_key'])
    chosen = options.detect { |title| title.downcase == message.content.to_s.strip.downcase }

    unless chosen
      retry_text = canned_text(account, step['retry_canned_response'], DEFAULT_RETRY_PROMPT)
      send_menu(conversation, step, retry_text)
      return false
    end

    team = team_for_name(account, chosen)
    conversation.update!(team: team) if team
    true
  end

  def handle_ask_and_extract_reply(conversation, message, step)
    return unless step['extract'] == 'cnpj'

    cnpj = message.content.to_s[CNPJ_REGEX]
    empresa = cnpj.present? ? lookup_empresa_by_cnpj(cnpj) : nil
    contact_name = conversation.contact.name.presence || 'tudo bem'

    content = if empresa
      canned_text(conversation.account, step['found_canned_response'], DEFAULT_KNOWN_COMPANY_REPLY, contact_name: contact_name, empresa_nome: empresa['nome'])
    else
      canned_text(conversation.account, step['not_found_canned_response'], DEFAULT_UNKNOWN_COMPANY_REPLY, contact_name: contact_name)
    end

    send_bot_message(conversation, content)
  end

  def attribute_values_for(account, attribute_key)
    return [] if attribute_key.blank?

    definition = account.custom_attribute_definitions.find_by(attribute_key: attribute_key, attribute_model: 'conversation_attribute')
    definition&.attribute_values || []
  end

  def team_for_name(account, name)
    account.teams.detect { |team| team.name.downcase == name.downcase }
  end

  def canned_text(account, short_code, default_template, vars = {})
    template =
      if short_code.present?
        account.canned_responses.find_by(short_code: short_code)&.content.presence || default_template
      else
        default_template
      end
    vars.present? ? format(template, vars) : template
  rescue KeyError, ArgumentError => e
    Rails.logger.error("[WhatsappBotFlowListener] resposta pronta '#{short_code}' com placeholder inválido (#{e.message}), usando texto padrão")
    vars.present? ? format(default_template, vars) : default_template
  end

  def set_step_index(conversation, index)
    conversation.update!(additional_attributes: conversation.additional_attributes.merge(STEP_INDEX_KEY => index))
  end

  def send_bot_message(conversation, content)
    return if content.blank?

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: content
    )
  end

  def send_menu(conversation, step, prompt_override = nil)
    account = conversation.account
    options = attribute_values_for(account, step['attribute_key'])
    prompt = prompt_override || canned_text(account, step['prompt_canned_response'], DEFAULT_MENU_PROMPT)

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: prompt,
      content_type: :input_select,
      content_attributes: {
        'items' => options.map { |title| { 'title' => title, 'value' => title.parameterize } }
      }
    )
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
    Rails.logger.error("[WhatsappBotFlowListener] erro ao buscar empresa por CNPJ: #{e.message}")
    nil
  end
end
