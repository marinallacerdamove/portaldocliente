# Interpretador do grafo (nodes/edges) de um BotFlow. O estado da conversa
# fica em additional_attributes (nunca custom_attributes - é dado interno,
# não pra aparecer pro agente): qual fluxo, em qual nó, e as variáveis já
# capturadas. Só "menu" e "ask_and_extract" pausam esperando resposta -
# os demais tipos executam e avançam sozinhos na mesma passada.
class BotFlows::Engine
  STATE_FLOW_KEY = 'bot_flow_id'.freeze
  STATE_NODE_KEY = 'bot_flow_node_id'.freeze
  STATE_VARS_KEY = 'bot_flow_vars'.freeze

  PRESET_PATTERNS = {
    'cnpj' => /\d{2}\.?\d{3}\.?\d{3}\/?\d{4}-?\d{2}/,
    'cpf' => /\d{3}\.?\d{3}\.?\d{3}-?\d{2}/,
    'email' => URI::MailTo::EMAIL_REGEXP,
    'telefone' => /\(?\d{2}\)?\s?\d{4,5}-?\d{4}/
  }.freeze

  DEFAULT_RETRY_TEXT = 'Não entendi sua escolha. Por favor, selecione uma das opções abaixo:'.freeze

  def initialize(conversation)
    @conversation = conversation
  end

  def running?
    @conversation.additional_attributes[STATE_NODE_KEY].present?
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
    loop do
      node = node_id && flow.nodes.find { |n| n['id'] == node_id }
      return clear_state unless node

      case node['type']
      when 'send_message'
        send_text(interpolate(node['text'], vars))
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
      when 'chatwoot_action'
        run_chatwoot_action(node)
        node_id = next_node_id(flow, node['id'], 'default')
      else
        node_id = next_node_id(flow, node['id'], 'default')
      end
    end
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
      send_menu(node, vars, retry_text: node['retry_prompt'].presence || DEFAULT_RETRY_TEXT)
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

  def run_chatwoot_action(node)
    BotFlows::ActionExecutor.new(@conversation).public_send(node['action_name'], node['action_params'])
  end

  def interpolate(template, vars)
    BotFlows::Interpolation.render(template, variables: vars, contact: @conversation.contact)
  end

  def send_text(content)
    return if content.blank?

    @conversation.messages.create!(
      account_id: @conversation.account_id, inbox_id: @conversation.inbox_id,
      message_type: :outgoing, content: content
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

  def set_state(flow_id, node_id, vars)
    @conversation.update!(additional_attributes: @conversation.additional_attributes.merge(
      STATE_FLOW_KEY => flow_id, STATE_NODE_KEY => node_id, STATE_VARS_KEY => vars
    ))
  end

  def clear_state
    @conversation.update!(
      additional_attributes: @conversation.additional_attributes.except(STATE_FLOW_KEY, STATE_NODE_KEY, STATE_VARS_KEY)
    )
  end
end
