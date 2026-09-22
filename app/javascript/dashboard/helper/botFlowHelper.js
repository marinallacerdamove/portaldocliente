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
      return { prompt: '', variable_name: '', variable_label: '' };
    case BOT_FLOW_NODE_TYPES.CONDITION:
      return { branches: [] };
    case BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN:
      return {
        source_variable: '',
        pattern: 'cnpj',
        custom_pattern: '',
        target_variable: '',
        target_variable_label: '',
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

// Transforma um rótulo amigável ("CNPJ do cliente") no identificador técnico
// usado dentro de {{...}} ("cnpj_do_cliente") - usado ao vivo enquanto a
// pessoa digita o nome da informação, pra ela nunca precisar pensar em slug.
export const slugifyVariableName = text =>
  (text || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');

// Blocos "prontos" (consulta de CNPJ) geram variáveis com nome fixo, que a
// pessoa não escolhe - por isso ficam catalogadas aqui, com o rótulo amigável
// (chave de i18n) e o tipo de dado, pro catálogo de variáveis conseguir
// mostrar/filtrar sem precisar adivinhar nada.
export const FIXED_OUTPUT_VARIABLES = {
  [BOT_FLOW_NODE_TYPES.CNPJ_LOOKUP]: [
    {
      id: 'empresa_nome',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.CNPJ_LOOKUP.EMPRESA_NOME',
      type: 'string',
    },
  ],
  [BOT_FLOW_NODE_TYPES.RECEITA_CNPJ_LOOKUP]: [
    {
      id: 'empresa_razao_social',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.RAZAO_SOCIAL',
      type: 'string',
    },
    {
      id: 'empresa_nome_fantasia',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.NOME_FANTASIA',
      type: 'string',
    },
    {
      id: 'empresa_cnae',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.CNAE',
      type: 'string',
    },
    {
      id: 'empresa_situacao',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.SITUACAO',
      type: 'string',
    },
    {
      id: 'empresa_porte',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.PORTE',
      type: 'string',
    },
    {
      id: 'empresa_telefone',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.TELEFONE',
      type: 'phone',
    },
    {
      id: 'empresa_data_abertura',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.DATA_ABERTURA',
      type: 'date',
    },
    {
      id: 'empresa_endereco',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.ENDERECO',
      type: 'string',
    },
    {
      id: 'empresa_logradouro',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.LOGRADOURO',
      type: 'string',
    },
    {
      id: 'empresa_numero',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.NUMERO',
      type: 'string',
    },
    {
      id: 'empresa_bairro',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.BAIRRO',
      type: 'string',
    },
    {
      id: 'empresa_municipio',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.MUNICIPIO',
      type: 'string',
    },
    {
      id: 'empresa_uf',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.UF',
      type: 'string',
    },
    {
      id: 'empresa_cep',
      labelKey: 'BOT_FLOW.EDITOR.VARIABLES.RECEITA.CEP',
      type: 'string',
    },
  ],
};

// Varre o grafo de trás pra frente a partir de um nó, juntando toda variável
// capturada por blocos "Pedir informação"/"Extrair padrão" e as saídas fixas
// dos blocos de consulta de CNPJ alcançáveis até ali - usado tanto pelo
// catálogo de variáveis (useVariableRegistry) quanto pela validação de
// referências quebradas (collectVariableWarnings) abaixo, sem duplicar a
// mesma busca duas vezes.
export const reachableFlowVariables = (nodes, edges, currentNodeId) => {
  if (!currentNodeId) return [];
  const nodesById = new Map(nodes.map(node => [node.id, node]));
  const visited = new Set();
  const queue = [currentNodeId];
  const found = new Map();

  while (queue.length) {
    const id = queue.shift();
    if (!visited.has(id)) {
      visited.add(id);

      edges
        .filter(edge => edge.target === id)
        .forEach(edge => {
          const sourceNode = nodesById.get(edge.source);
          if (sourceNode) {
            if (
              sourceNode.type === BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT &&
              sourceNode.data?.variable_name
            ) {
              found.set(sourceNode.data.variable_name, {
                id: sourceNode.data.variable_name,
                label: sourceNode.data.variable_label || null,
                type: 'string',
                sourceNodeId: sourceNode.id,
                sourceNodeType: sourceNode.type,
              });
            }
            if (
              sourceNode.type === BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN &&
              sourceNode.data?.target_variable
            ) {
              found.set(sourceNode.data.target_variable, {
                id: sourceNode.data.target_variable,
                label: sourceNode.data.target_variable_label || null,
                type: 'string',
                sourceNodeId: sourceNode.id,
                sourceNodeType: sourceNode.type,
              });
            }
            (FIXED_OUTPUT_VARIABLES[sourceNode.type] || []).forEach(output => {
              found.set(output.id, {
                id: output.id,
                label: null,
                labelKey: output.labelKey,
                type: output.type,
                sourceNodeId: sourceNode.id,
                sourceNodeType: sourceNode.type,
              });
            });
          }
          queue.push(edge.source);
        });
    }
  }

  return [...found.values()];
};

// {{contact.name}}, {{contact.custom_attributes.cpf}}, {{detalhes}}... -
// mesmos formatos que BotFlows::Interpolation resolve no backend.
const REFERENCE_REGEX = /\{\{([\w.-]+)\}\}/g;

// Campos de texto livre (podem ter várias referências {{...}} misturadas com
// texto) x campos de seleção única (guardam só o id de uma variável) - usados
// pra saber onde procurar referência quebrada em cada tipo de bloco.
const TEXT_FIELDS_BY_TYPE = {
  [BOT_FLOW_NODE_TYPES.SEND_MESSAGE]: ['text'],
  [BOT_FLOW_NODE_TYPES.MENU]: ['prompt', 'retry_prompt'],
  [BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT]: ['prompt'],
  [BOT_FLOW_NODE_TYPES.WEBHOOK]: ['url', 'body_template'],
};
const SELECT_FIELDS_BY_TYPE = {
  [BOT_FLOW_NODE_TYPES.CNPJ_LOOKUP]: ['source_variable'],
  [BOT_FLOW_NODE_TYPES.RECEITA_CNPJ_LOOKUP]: ['source_variable'],
  [BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN]: ['source_variable'],
};

// Campos padrão (schema do Chatwoot, não muda por conta) que sempre resolvem
// em runtime - espelha exatamente o que BotFlows::Interpolation.resolve
// entende no backend, fora o hash de variáveis capturadas e os custom
// attributes (esses dois são passados por fora, ver contactAttributeKeys/
// conversationAttributeKeys abaixo).
const STANDARD_REFERENCES = [
  'contact.name',
  'contact.email',
  'contact.phone_number',
  'contact.identifier',
  'conversation.id',
  'conversation.status',
  'conversation.priority',
  'inbox.name',
  'agent.name',
  'agent.email',
];

// Avisos (não bloqueantes) pra ajudar a manter o fluxo consistente: referência
// a uma variável que não existe mais (bloco removido, custom attribute
// excluído no Chatwoot) e nomes de resposta duplicados entre blocos.
export const collectVariableWarnings = (
  nodes,
  edges,
  { contactAttributeKeys = [], conversationAttributeKeys = [] } = {}
) => {
  const warnings = [];

  const isKnownReference = (ref, reachableIds) => {
    if (reachableIds.has(ref)) return true;
    if (STANDARD_REFERENCES.includes(ref)) return true;
    const contactCustomMatch = ref.match(/^contact\.custom_attributes\.(.+)$/);
    if (contactCustomMatch) {
      return contactAttributeKeys.includes(contactCustomMatch[1]);
    }
    const conversationCustomMatch = ref.match(
      /^conversation\.custom_attributes\.(.+)$/
    );
    if (conversationCustomMatch) {
      return conversationAttributeKeys.includes(conversationCustomMatch[1]);
    }
    return false;
  };

  nodes.forEach(node => {
    const reachableIds = new Set(
      reachableFlowVariables(nodes, edges, node.id).map(v => v.id)
    );

    (TEXT_FIELDS_BY_TYPE[node.type] || []).forEach(field => {
      const value = node.data?.[field];
      if (!value) return;
      [...value.matchAll(REFERENCE_REGEX)].forEach(([, ref]) => {
        if (!isKnownReference(ref, reachableIds)) {
          warnings.push({
            nodeId: node.id,
            field,
            ref,
            type: 'stale_reference',
          });
        }
      });
    });

    (SELECT_FIELDS_BY_TYPE[node.type] || []).forEach(field => {
      const value = node.data?.[field];
      if (!value) return;
      if (!isKnownReference(value, reachableIds)) {
        warnings.push({
          nodeId: node.id,
          field,
          ref: value,
          type: 'stale_reference',
        });
      }
    });
  });

  const nodeIdsByName = new Map();
  nodes.forEach(node => {
    let name = null;
    if (node.type === BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT) {
      name = node.data?.variable_name;
    } else if (node.type === BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN) {
      name = node.data?.target_variable;
    }
    if (!name) return;
    if (!nodeIdsByName.has(name)) nodeIdsByName.set(name, []);
    nodeIdsByName.get(name).push(node.id);
  });
  nodeIdsByName.forEach((nodeIds, name) => {
    if (nodeIds.length < 2) return;
    nodeIds.forEach(nodeId => {
      warnings.push({
        nodeId,
        field: 'variable_name',
        ref: name,
        type: 'duplicate_name',
      });
    });
  });

  return warnings;
};
