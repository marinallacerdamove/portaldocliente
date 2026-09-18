export const BOT_FLOW_NODE_TYPES = {
  START: 'start',
  SEND_MESSAGE: 'send_message',
  MENU: 'menu',
  ASK_AND_EXTRACT: 'ask_and_extract',
  CONDITION: 'condition',
  EXTRACT_PATTERN: 'extract_pattern',
  WEBHOOK: 'webhook',
  CHATWOOT_ACTION: 'chatwoot_action',
  CNPJ_LOOKUP: 'cnpj_lookup',
  RECEITA_CNPJ_LOOKUP: 'receita_cnpj_lookup',
};

export const BOT_FLOW_ADDABLE_NODE_TYPES = [
  BOT_FLOW_NODE_TYPES.SEND_MESSAGE,
  BOT_FLOW_NODE_TYPES.MENU,
  BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT,
  BOT_FLOW_NODE_TYPES.CONDITION,
  BOT_FLOW_NODE_TYPES.CNPJ_LOOKUP,
  BOT_FLOW_NODE_TYPES.RECEITA_CNPJ_LOOKUP,
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
      return { text: '', private: false };
    case BOT_FLOW_NODE_TYPES.MENU:
      return { prompt: '', retry_prompt: '', options: [] };
    case BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT:
      return { prompt: '', variable_name: '' };
    case BOT_FLOW_NODE_TYPES.CONDITION:
      return { branches: [] };
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
    case BOT_FLOW_NODE_TYPES.CNPJ_LOOKUP:
    case BOT_FLOW_NODE_TYPES.RECEITA_CNPJ_LOOKUP:
      return { source_variable: '' };
    default:
      return {};
  }
};

let optionIdCounter = 0;
export const generateOptionId = () => {
  optionIdCounter += 1;
  return `opt${optionIdCounter}_${Date.now().toString(36)}`;
};

let idSeq = 0;
export const generateBranchId = () => {
  idSeq += 1;
  return `branch${idSeq}_${Date.now().toString(36)}`;
};
export const generateConditionId = () => {
  idSeq += 1;
  return `cond${idSeq}_${Date.now().toString(36)}`;
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
    case BOT_FLOW_NODE_TYPES.CNPJ_LOOKUP:
    case BOT_FLOW_NODE_TYPES.RECEITA_CNPJ_LOOKUP:
      return ['found', 'not_found'];
    case BOT_FLOW_NODE_TYPES.WEBHOOK:
      return ['success', 'error'];
    default:
      return [];
  }
};

// Menu e Condição têm um número dinâmico de saídas (uma por opção/caminho,
// mais "senão" na Condição) - calculadas a partir dos dados do próprio nó.
export const dynamicHandlesFor = data => {
  if (!data) return [];
  if (Array.isArray(data.options)) {
    return data.options.map(option => `option-${option.id}`);
  }
  if (Array.isArray(data.branches)) {
    return [...data.branches.map(branch => `branch-${branch.id}`), 'else'];
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
  [BOT_FLOW_NODE_TYPES.CONDITION]: ['branches'],
  [BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN]: [
    'source_variable',
    'pattern',
    'target_variable',
  ],
  [BOT_FLOW_NODE_TYPES.WEBHOOK]: ['url', 'method'],
  [BOT_FLOW_NODE_TYPES.CHATWOOT_ACTION]: ['action_name'],
  [BOT_FLOW_NODE_TYPES.CNPJ_LOOKUP]: ['source_variable'],
  [BOT_FLOW_NODE_TYPES.RECEITA_CNPJ_LOOKUP]: ['source_variable'],
};

const isBranchValid = branch =>
  Array.isArray(branch.conditions) &&
  branch.conditions.length > 0 &&
  branch.conditions.every(
    condition =>
      condition.variable &&
      (condition.operator === 'is_present' || condition.value)
  );

export const isNodeValid = node => {
  if (node.type === BOT_FLOW_NODE_TYPES.CONDITION) {
    const branches = node.data?.branches;
    return (
      Array.isArray(branches) &&
      branches.length > 0 &&
      branches.every(isBranchValid)
    );
  }

  const required = REQUIRED_FIELDS_BY_TYPE[node.type] || [];
  return required.every(field => {
    const value = node.data?.[field];
    if (Array.isArray(value)) return value.length > 0;
    return !!value;
  });
};

const LAYOUT_COLUMN_WIDTH = 280;
const LAYOUT_ROW_HEIGHT = 160;
const LAYOUT_OFFSET = 80;

// Reorganiza o canvas em colunas (uma por "distância" a partir do Início),
// seguindo as arestas - resolve o caso comum de nós empilhados/desorganizados
// sem precisar arrastar um por um.
export const autoLayoutPositions = (nodes, edges) => {
  const adjacency = new Map();
  edges.forEach(edge => {
    if (!adjacency.has(edge.source)) adjacency.set(edge.source, []);
    adjacency.get(edge.source).push(edge.target);
  });

  const startNode = nodes.find(node => node.type === BOT_FLOW_NODE_TYPES.START);
  const layerById = new Map();
  if (startNode) {
    layerById.set(startNode.id, 0);
    const queue = [startNode.id];
    while (queue.length) {
      const id = queue.shift();
      (adjacency.get(id) || []).forEach(targetId => {
        const candidateLayer = layerById.get(id) + 1;
        if (
          !layerById.has(targetId) ||
          candidateLayer > layerById.get(targetId)
        ) {
          layerById.set(targetId, candidateLayer);
          queue.push(targetId);
        }
      });
    }
  }
  nodes.forEach(node => {
    if (!layerById.has(node.id)) layerById.set(node.id, 0);
  });

  const nodesByLayer = new Map();
  nodes.forEach(node => {
    const layer = layerById.get(node.id);
    if (!nodesByLayer.has(layer)) nodesByLayer.set(layer, []);
    nodesByLayer.get(layer).push(node.id);
  });

  return nodes.map(node => {
    const layer = layerById.get(node.id);
    const rowIndex = nodesByLayer.get(layer).indexOf(node.id);
    return {
      ...node,
      position: {
        x: LAYOUT_OFFSET + layer * LAYOUT_COLUMN_WIDTH,
        y: LAYOUT_OFFSET + rowIndex * LAYOUT_ROW_HEIGHT,
      },
    };
  });
};
