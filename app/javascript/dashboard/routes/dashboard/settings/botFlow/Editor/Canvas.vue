<script setup>
import { markRaw, watch } from 'vue';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { MiniMap } from '@vue-flow/minimap';
import BotFlowNode from './nodes/BotFlowNode.vue';
import { BOT_FLOW_NODE_TYPES } from 'dashboard/helper/botFlowHelper';

import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import '@vue-flow/controls/dist/style.css';
import '@vue-flow/minimap/dist/style.css';

const props = defineProps({
  selectedNodeId: { type: String, default: null },
});
const emit = defineEmits(['selectNode', 'beforeChange']);
const nodes = defineModel('nodes', { type: Array, required: true });
const edges = defineModel('edges', { type: Array, required: true });
const nodeTypes = Object.fromEntries(
  Object.values(BOT_FLOW_NODE_TYPES).map(type => [type, markRaw(BotFlowNode)])
);

const { onConnect, addEdges, onNodeClick, onPaneClick, onNodeDragStart } =
  useVueFlow();

onConnect(connection => {
  emit('beforeChange');
  addEdges([connection]);
});
onNodeDragStart(() => emit('beforeChange'));
onNodeClick(({ node }) => emit('selectNode', node.id));
onPaneClick(() => emit('selectNode', null));

// Destaca as conexões do bloco selecionado, apaga o resto - sem isso, um
// fluxo com muitos blocos vira uma tela cheia de linhas cruzadas difíceis
// de seguir. Mutamos class/animated direto nos objetos de edges (campos só
// visuais - flowEdgeToBackend, no Editor/Index.vue, já ignora tudo que não
// seja source/target/sourceHandle na hora de salvar).
watch(
  () => props.selectedNodeId,
  selectedNodeId => {
    edges.value.forEach(edge => {
      const isConnected =
        selectedNodeId &&
        (edge.source === selectedNodeId || edge.target === selectedNodeId);
      edge.class = selectedNodeId && !isConnected ? 'opacity-20' : '';
      edge.animated = !!isConnected;
    });
  },
  { immediate: true }
);
</script>

<template>
  <VueFlow
    v-model:nodes="nodes"
    v-model:edges="edges"
    :node-types="nodeTypes"
    :default-viewport="{ zoom: 1 }"
    :min-zoom="0.2"
    :max-zoom="1.5"
    fit-view-on-init
    class="w-full h-full"
  >
    <Background :gap="16" />
    <Controls />
    <MiniMap />
  </VueFlow>
</template>
