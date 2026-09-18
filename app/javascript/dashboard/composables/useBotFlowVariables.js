import { computed, toValue } from 'vue';
import { BOT_FLOW_NODE_TYPES } from 'dashboard/helper/botFlowHelper';

// Variáveis que já existem automaticamente em qualquer fluxo (preenchidas
// pelo Chatwoot, não precisam de nenhum bloco "Perguntar e capturar") -
// espelha exatamente o que BotFlows::Interpolation entende no backend.
const SYSTEM_VARIABLES = [
  { id: 'contact.name', label: 'Nome do cliente' },
  { id: 'contact.email', label: 'E-mail do cliente' },
  { id: 'contact.phone_number', label: 'Telefone do cliente' },
];

const formatOption = (id, label) => ({ id, name: `${label} — {{${id}}}` });

// Lista as variáveis já capturadas antes de um nó (varre as arestas de trás
// pra frente) - usado pra oferecer um dropdown de variável em vez de pedir
// pra digitar o nome de cor, e reduzir erro de digitação/nome inventado.
// nodes/edges/currentNodeId podem ser refs, computeds ou funções (getters) -
// toValue() resolve qualquer um dos três mantendo a reatividade.
export function useBotFlowVariables(nodes, edges, currentNodeId) {
  const variableOptions = computed(() => {
    const nodeList = toValue(nodes) || [];
    const edgeList = toValue(edges) || [];
    const startId = toValue(currentNodeId);
    if (!startId) return [];

    const nodesById = new Map(nodeList.map(node => [node.id, node]));
    const visited = new Set();
    const queue = [startId];
    const names = new Set();

    while (queue.length) {
      const id = queue.shift();
      if (!visited.has(id)) {
        visited.add(id);

        edgeList
          .filter(edge => edge.target === id)
          .forEach(edge => {
            const sourceNode = nodesById.get(edge.source);
            if (sourceNode) {
              if (
                sourceNode.type === BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT &&
                sourceNode.data?.variable_name
              ) {
                names.add(sourceNode.data.variable_name);
              }
              if (
                sourceNode.type === BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN &&
                sourceNode.data?.target_variable
              ) {
                names.add(sourceNode.data.target_variable);
              }
            }
            queue.push(edge.source);
          });
      }
    }

    return [...names].map(name => formatOption(name, name));
  });

  // Pras condições/extrações, só as variáveis capturadas no fluxo fazem
  // sentido (contact.name não existe dentro dos dados capturados, só em
  // texto interpolado) - pros campos de texto (mensagem, URL, corpo do
  // webhook), as duas fontes valem, porque o backend interpola as duas.
  const insertableVariableOptions = computed(() => [
    ...variableOptions.value,
    ...SYSTEM_VARIABLES.map(v => formatOption(v.id, v.label)),
  ]);

  return { variableOptions, insertableVariableOptions };
}
