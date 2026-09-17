export const BOT_FLOW_NODE_TYPES = {
  START: 'start',
  SEND_MESSAGE: 'send_message',
  MENU: 'menu',
  ASK_AND_EXTRACT: 'ask_and_extract',
  CONDITION: 'condition',
  EXTRACT_PATTERN: 'extract_pattern',
  WEBHOOK: 'webhook',
  CHATWOOT_ACTION: 'chatwoot_action',
};

export const BOT_FLOW_ADDABLE_NODE_TYPES = [
  BOT_FLOW_NODE_TYPES.SEND_MESSAGE,
  BOT_FLOW_NODE_TYPES.MENU,
  BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT,
  BOT_FLOW_NODE_TYPES.CONDITION,
  BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN,
  BOT_FLOW_NODE_TYPES.WEBHOOK,
  BOT_FLOW_NODE_TYPES.CHATWOOT_ACTION,
];

let idCounter = 0;
export const generateNodeId = type => {
  idCounter += 1;
  return `${type}_${Date.now().toString(36)}_${idCounter}`;
};

export const getDefaultNodeData = type => {
  switch (type) {
    case BOT_FLOW_NODE_TYPES.SEND_MESSAGE:
      return { text: '' };
    case BOT_FLOW_NODE_TYPES.MENU:
      return { prompt: '', retry_prompt: '', options: [] };
    case BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT:
      return { prompt: '', variable_name: '' };
    case BOT_FLOW_NODE_TYPES.CONDITION:
      return { variable: '', rules: [] };
    case BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN:
      return {
        source_variable: '',
        pattern: 'cnpj',
        custom_pattern: '',
        target_variable: '',
      };
    case BOT_FLOW_NODE_TYPES.WEBHOOK:
      return {
        method: 'get',
        url: '',
        headers: [],
        body_template: '',
        success_check: null,
        response_mappings: [],
      };
    case BOT_FLOW_NODE_TYPES.CHATWOOT_ACTION:
      return { action_name: 'assign_team', action_params: [] };
    default:
      return {};
  }
};

let optionIdCounter = 0;
export const generateOptionId = () => {
  optionIdCounter += 1;
  return `opt${optionIdCounter}_${Date.now().toString(36)}`;
};

let ruleIdCounter = 0;
export const generateRuleId = () => {
  ruleIdCounter += 1;
  return `rule${ruleIdCounter}_${Date.now().toString(36)}`;
};

// Handles (saídas) de cada tipo de nó no canvas - usados tanto pra desenhar
// os conectores quanto pra montar o campo sourceHandle de cada edge salva.
export const staticHandlesFor = type => {
  switch (type) {
    case BOT_FLOW_NODE_TYPES.START:
    case BOT_FLOW_NODE_TYPES.SEND_MESSAGE:
    case BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT:
    case BOT_FLOW_NODE_TYPES.CHATWOOT_ACTION:
      return ['default'];
    case BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN:
      return ['found', 'not_found'];
    case BOT_FLOW_NODE_TYPES.WEBHOOK:
      return ['success', 'error'];
    default:
      return [];
  }
};

// Menu e Condição têm um número dinâmico de saídas (uma por opção/regra,
// mais "senão" na Condição) - calculadas a partir dos dados do próprio nó.
export const dynamicHandlesFor = data => {
  if (!data) return [];
  if (Array.isArray(data.options)) {
    return data.options.map(option => `option-${option.id}`);
  }
  if (Array.isArray(data.rules)) {
    return [...data.rules.map(rule => `rule-${rule.id}`), 'else'];
  }
  return [];
};

export const handlesForNode = node => {
  const staticHandles = staticHandlesFor(node.type);
  return staticHandles.length ? staticHandles : dynamicHandlesFor(node.data);
};

const REQUIRED_FIELDS_BY_TYPE = {
  [BOT_FLOW_NODE_TYPES.START]: [],
  [BOT_FLOW_NODE_TYPES.SEND_MESSAGE]: ['text'],
  [BOT_FLOW_NODE_TYPES.MENU]: ['prompt', 'options'],
  [BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT]: ['prompt', 'variable_name'],
  [BOT_FLOW_NODE_TYPES.CONDITION]: ['variable', 'rules'],
  [BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN]: [
    'source_variable',
    'pattern',
    'target_variable',
  ],
  [BOT_FLOW_NODE_TYPES.WEBHOOK]: ['url', 'method'],
  [BOT_FLOW_NODE_TYPES.CHATWOOT_ACTION]: ['action_name'],
};

export const isNodeValid = node => {
  const required = REQUIRED_FIELDS_BY_TYPE[node.type] || [];
  return required.every(field => {
    const value = node.data?.[field];
    if (Array.isArray(value)) return value.length > 0;
    return !!value;
  });
};
