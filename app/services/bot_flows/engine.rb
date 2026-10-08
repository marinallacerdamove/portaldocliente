# Interpretador do grafo (nodes/edges) de um BotFlow. O estado da conversa
# fica em additional_attributes (nunca custom_attributes - é dado interno,
# não pra aparecer pro agente): qual fluxo, em qual nó, e as variáveis já
# capturadas. Só "menu" e "ask_and_extract" pausam esperando resposta -
# os demais tipos executam e avançam sozinhos na mesma passada.
class BotFlows::Engine
  STATE_FLOW_KEY = 'bot_flow_id'.freeze
  STATE_NODE_KEY = 'bot_flow_node_id'.freeze
  STATE_VARS_KEY = 'bot_flow_vars'.freeze
  STATE_STARTED_AT_KEY = 'bot_flow_started_at'.freeze
  STATE_RETRIES_KEY = 'bot_flow_menu_retries'.freeze
  STATE_KEYS = [STATE_FLOW_KEY, STATE_NODE_KEY, STATE_VARS_KEY, STATE_STARTED_AT_KEY, STATE_RETRIES_KEY].freeze

  # Ciclo entre nós que não pausam (ex. webhook erro -> mensagem -> webhook)
  # mandaria mensagem sem parar; nenhum fluxo legítimo passa disso sem pausar.
  MAX_STEPS = 50
  # Fluxo parado esperando resposta há mais que isso (ou sem registro de quando
  # parou) é abandonado: o cliente que volta depois não recebe o menu antigo.
  STATE_TTL = 24.hours
  # Respostas que não batem com nenhuma opção do menu antes de desistir.
  MAX_MENU_RETRIES = 2

  PRESET_PATTERNS = {
    'cnpj' => BotFlows::CnpjLookup::CNPJ_REGEX,
    'cpf' => /\d{3}\.?\d{3}\.?\d{3}-?\d{2}/,
    'email' => URI::MailTo::EMAIL_REGEXP,
    'telefone' => /\(?\d{2}\)?\s?\d{4,5}-?\d{4}/
  }.freeze

  DEFAULT_RETRY_TEXT = 'Não entendi sua escolha. Por favor, selecione uma das opções abaixo:'.freeze

  def initialize(conversation)
    @conversation = conversation
  end

  def running?
    @conversation.additional_attributes[STATE_NODE_KEY].present? && !state_expired?
  end

  # Atendimento humano assumiu ou a conversa foi resolvida: o fluxo para.
  def stop
    clear_state if @conversation.additional_attributes[STATE_NODE_KEY].present?
  end

  def start(flow)
    start_node = flow.nodes.find { |n| n['type'] == 'start' }
    return unless start_node

    run_from(flow, next_node_id(flow, start_node['id'], 'default'), {})
  end

  def resume(message)
    flow = @conversation.account.bot_flows.find_by(id: @conversation.additional_attributes[STATE_FLOW_KEY])
    return clear_state unless flow

    node = flow.nodes.find { |n| n['id'] == @conversation.additional_attributes[STATE_NODE_KEY] }
    return clear_state unless node

    vars = @conversation.additional_attributes[STATE_VARS_KEY] || {}

    case node['type']
    when 'menu'
      handle_menu_reply(flow, node, message, vars)
    when 'ask_and_extract'
      vars = vars.merge(node['variable_name'] => message.content.to_s)
      run_from(flow, next_node_id(flow, node['id'], 'default'), vars)
    else
      clear_state
    end
  end

  private

  def run_from(flow, node_id, vars)
    MAX_STEPS.times do
      node = node_id && flow.nodes.find { |n| n['id'] == node_id }
      return clear_state unless node

      case node['type']
      when 'send_message'
        send_text(interpolate(node['text'], vars), private: node['private'].present?)
        node_id = next_node_id(flow, node['id'], 'default')
      when 'menu'
        send_menu(node, vars)
        return set_state(flow.id, node['id'], vars)
      when 'ask_and_extract'
        send_text(interpolate(node['prompt'], vars))
        return set_state(flow.id, node['id'], vars)
      when 'condition'
        node_id = next_node_id(flow, node['id'], evaluate_condition(node, vars))
      when 'extract_pattern'
        handle, vars = run_extract(node, vars)
        node_id = next_node_id(flow, node['id'], handle)
      when 'webhook'
        handle, vars = BotFlows::WebhookCaller.new(node, vars, @conversation).call
        node_id = next_node_id(flow, node['id'], handle)
      when 'cnpj_lookup'
        handle, vars = BotFlows::CnpjLookup.new(node, vars, @conversation).call
        node_id = next_node_id(flow, node['id'], handle)
      when 'receita_cnpj_lookup'
        handle, vars = BotFlows::ReceitaCnpjLookup.new(node, vars, @conversation).call
        node_id = next_node_id(flow, node['id'], handle)
      when 'chatwoot_action'
        run_chatwoot_action(node)
        node_id = next_node_id(flow, node['id'], 'default')
      else
        node_id = next_node_id(flow, node['id'], 'default')
      end
    end
    Rails.logger.warn("[BotFlows::Engine] flow #{flow.id} passed #{MAX_STEPS} steps without pausing in conversation #{@conversation.id}")
    clear_state
  end

  def next_node_id(flow, from_id, handle)
    flow.edges.find { |e| e['source'] == from_id && e['sourceHandle'] == handle }&.dig('target')
  end

  # O WhatsApp achata a resposta de um menu interativo pro texto do título
  # da opção antes de chegar no Chatwoot - por isso a comparação é por
  # texto (label), não por um id interno da opção.
  def handle_menu_reply(flow, node, message, vars)
    options = node['options'] || []
    chosen = options.detect { |o| o['label'].to_s.strip.casecmp(message.content.to_s.strip).zero? }

    unless chosen
      retry_menu(node, vars)
      return
    end

    run_from(flow, next_node_id(flow, node['id'], "option-#{chosen['id']}"), vars)
  end

  # Cada branch é um caminho de saída que testa uma ou mais condições
  # (cada uma com sua própria variável), combinadas por "and" (todas
  # precisam bater) ou "or" (qualquer uma). O primeiro branch que bater
  # vence; se nenhum bater, cai no "else".
  def evaluate_condition(node, vars)
    branch = (node['branches'] || []).detect { |b| branch_matches?(b, vars) }
    branch ? "branch-#{branch['id']}" : 'else'
  end

  def branch_matches?(branch, vars)
    conditions = branch['conditions'] || []
    return false if conditions.empty?

    results = conditions.map { |condition| rule_matches?(condition, vars[condition['variable']].to_s) }
    branch['logic'] == 'or' ? results.any? : results.all?
  end

  def rule_matches?(rule, value)
    case rule['operator']
    when 'equals' then value.casecmp(rule['value'].to_s).zero?
    when 'contains' then value.downcase.include?(rule['value'].to_s.downcase)
    when 'is_present' then value.present?
    when 'regex'
      begin
        Regexp.new(rule['value'].to_s).match?(value)
      rescue RegexpError
        false
      end
    else
      false
    end
  end

  def run_extract(node, vars)
    regex = node['pattern'] == 'personalizado' ? safe_custom_regex(node['custom_pattern']) : PRESET_PATTERNS[node['pattern']]
    match = regex&.match(vars[node['source_variable']].to_s)
    return ['not_found', vars] unless match

    ['found', vars.merge(node['target_variable'] => match[0])]
  end

  def safe_custom_regex(pattern)
    Regexp.new(pattern.to_s)
  rescue RegexpError
    nil
  end

  # Fluxo gravado antes da validação do model também não chama nada fora da lista.
  def run_chatwoot_action(node)
    return unless BotFlow::CHATWOOT_ACTIONS.include?(node['action_name'])

    BotFlows::ActionExecutor.new(@conversation).public_send(node['action_name'], node['action_params'])
  end

  def interpolate(template, vars)
    BotFlows::Interpolation.render(template, variables: vars, conversation: @conversation)
  end

  def send_text(content, private: false)
    return if content.blank?

    @conversation.messages.create!(
      account_id: @conversation.account_id, inbox_id: @conversation.inbox_id,
      message_type: :outgoing, content: content, private: private
    )
  end

  def send_menu(node, vars, retry_text: nil)
    prompt = retry_text || interpolate(node['prompt'], vars)
    options = node['options'] || []

    @conversation.messages.create!(
      account_id: @conversation.account_id, inbox_id: @conversation.inbox_id,
      message_type: :outgoing, content: prompt, content_type: :input_select,
      content_attributes: { 'items' => options.map { |o| { 'title' => o['label'], 'value' => o['id'] } } }
    )
  end

  # Reapresenta o menu até MAX_MENU_RETRIES vezes; depois desiste (o cliente
  # pode estar falando com uma pessoa) em vez de repetir pra sempre.
  def retry_menu(node, vars)
    retries = @conversation.additional_attributes[STATE_RETRIES_KEY].to_i
    return clear_state if retries >= MAX_MENU_RETRIES

    @conversation.update!(additional_attributes: @conversation.additional_attributes.merge(STATE_RETRIES_KEY => retries + 1))
    send_menu(node, vars, retry_text: node['retry_prompt'].presence || DEFAULT_RETRY_TEXT)
  end

  def state_expired?
    started_at = @conversation.additional_attributes[STATE_STARTED_AT_KEY]
    started_at.blank? || Time.zone.at(started_at.to_i) < STATE_TTL.ago
  end

  def set_state(flow_id, node_id, vars)
    @conversation.update!(additional_attributes: @conversation.additional_attributes.merge(
      STATE_FLOW_KEY => flow_id, STATE_NODE_KEY => node_id, STATE_VARS_KEY => vars,
      STATE_STARTED_AT_KEY => Time.current.to_i, STATE_RETRIES_KEY => 0
    ))
  end

  def clear_state
    @conversation.update!(additional_attributes: @conversation.additional_attributes.except(*STATE_KEYS))
  end
end
