import { computed, unref } from 'vue';
import { BOT_FLOW_NODE_TYPES } from 'dashboard/helper/botFlowHelper';

// Lista as variáveis já capturadas antes de um nó (varre as arestas de trás
// pra frente) - usado pra oferecer um dropdown de variável em vez de pedir
// pra digitar o nome de cor, e reduzir erro de digitação/nome inventado.
export function useBotFlowVariables(nodes, edges, currentNodeId) {
  const variableOptions = computed(() => {
    const nodeList = unref(nodes) || [];
    const edgeList = unref(edges) || [];
    const startId = unref(currentNodeId);
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

    return [...names].map(name => ({ id: name, name }));
  });

  return { variableOptions };
}
