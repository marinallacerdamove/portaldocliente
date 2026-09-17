<script setup>
import { markRaw } from 'vue';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import BotFlowNode from './nodes/BotFlowNode.vue';
import { BOT_FLOW_NODE_TYPES } from 'dashboard/helper/botFlowHelper';

import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import '@vue-flow/controls/dist/style.css';

const emit = defineEmits(['selectNode']);
const nodes = defineModel('nodes', { type: Array, required: true });
const edges = defineModel('edges', { type: Array, required: true });
const nodeTypes = Object.fromEntries(
  Object.values(BOT_FLOW_NODE_TYPES).map(type => [type, markRaw(BotFlowNode)])
);

const { onConnect, addEdges, onNodeClick, onPaneClick } = useVueFlow();

onConnect(connection => addEdges([connection]));
onNodeClick(({ node }) => emit('selectNode', node.id));
onPaneClick(() => emit('selectNode', null));
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
  </VueFlow>
</template>
