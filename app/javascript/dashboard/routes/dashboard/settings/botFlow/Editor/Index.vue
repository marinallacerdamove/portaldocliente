<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import MultiSelect from 'dashboard/components-next/filter/inputs/MultiSelect.vue';
import Canvas from './Canvas.vue';
import PropertyPanel from './PropertyPanel.vue';
import {
  BOT_FLOW_NODE_TYPES,
  BOT_FLOW_ADDABLE_NODE_TYPES,
  generateNodeId,
  getDefaultNodeData,
  isNodeValid,
  autoLayoutPositions,
} from 'dashboard/helper/botFlowHelper';

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const botFlowId = computed(() => route.params.botFlowId);
const isEditing = computed(() => !!botFlowId.value);

const botFlows = useMapGetter('botFlows/getBotFlows');
const inboxes = useMapGetter('inboxes/getInboxes');
const whatsappInboxOptions = computed(() =>
  inboxes.value
    .filter(inbox => inbox.channel_type === 'Channel::Whatsapp')
    .map(inbox => ({ id: inbox.id, name: inbox.name }))
);

const name = ref('');
const description = ref('');
const active = ref(true);
const triggerType = ref('conversation_created');
const keywordsText = ref('');
const selectedInboxes = ref([]);
const isSaving = ref(false);

const nodes = ref([]);
const edges = ref([]);
const selectedNodeId = ref(null);
const selectedNode = computed(
  () => nodes.value.find(n => n.id === selectedNodeId.value) || null
);

// Desfazer/refazer: pilha de fotos do estado (nodes+edges) antes de cada
// ação estrutural (adicionar/excluir/duplicar/organizar/conectar/mover) -
// edição de texto dentro do painel não entra aqui de propósito.
const undoStack = ref([]);
const redoStack = ref([]);
const snapshot = () =>
  structuredClone({ nodes: nodes.value, edges: edges.value });
const pushHistory = () => {
  undoStack.value.push(snapshot());
  redoStack.value = [];
};
const undo = () => {
  if (!undoStack.value.length) return;
  redoStack.value.push(snapshot());
  const previous = undoStack.value.pop();
  nodes.value = previous.nodes;
  edges.value = previous.edges;
  selectedNodeId.value = null;
};
const redo = () => {
  if (!redoStack.value.length) return;
  undoStack.value.push(snapshot());
  const next = redoStack.value.pop();
  nodes.value = next.nodes;
  edges.value = next.edges;
  selectedNodeId.value = null;
};

const triggerTypeOptions = computed(() => [
  {
    id: 'conversation_created',
    name: t('BOT_FLOW.EDITOR.TRIGGER_TYPES.CONVERSATION_CREATED'),
  },
  { id: 'keyword', name: t('BOT_FLOW.EDITOR.TRIGGER_TYPES.KEYWORD') },
]);
const triggerTypeModel = computed({
  get: () =>
    triggerTypeOptions.value.find(o => o.id === triggerType.value) ||
    triggerTypeOptions.value[0],
  set: option => {
    triggerType.value = option?.id || 'conversation_created';
  },
});

const addNodeOptions = computed(() =>
  BOT_FLOW_ADDABLE_NODE_TYPES.map(type => ({
    id: type,
    name: t(`BOT_FLOW.EDITOR.NODE_TYPES.${type.toUpperCase()}`),
  }))
);

const backendNodeToFlow = node => {
  const { id, type, position, ...data } = node;
  return { id, type, position: position || { x: 100, y: 100 }, data };
};

const backendEdgeToFlow = (edge, index) => ({
  id: `e-${index}-${edge.source}-${edge.sourceHandle}-${edge.target}`,
  source: edge.source,
  target: edge.target,
  sourceHandle: edge.sourceHandle,
});

const flowNodeToBackend = node => ({
  id: node.id,
  type: node.type,
  position: node.position,
  ...node.data,
});
const flowEdgeToBackend = edge => ({
  source: edge.source,
  target: edge.target,
  sourceHandle: edge.sourceHandle,
});

const loadFlow = flow => {
  name.value = flow.name;
  description.value = flow.description || '';
  active.value = flow.active;
  triggerType.value = flow.trigger_type;
  keywordsText.value = (flow.trigger_config?.keywords || []).join(', ');
  selectedInboxes.value = (flow.inbox_ids || [])
    .map(id => whatsappInboxOptions.value.find(o => o.id === id))
    .filter(Boolean);
  nodes.value = (flow.nodes || []).map(backendNodeToFlow);
  edges.value = (flow.edges || []).map(backendEdgeToFlow);
};

const initNewFlow = () => {
  nodes.value = [
    {
      id: generateNodeId('start'),
      type: BOT_FLOW_NODE_TYPES.START,
      position: { x: 60, y: 200 },
      data: {},
    },
  ];
  edges.value = [];
};

onMounted(async () => {
  if (!inboxes.value.length) await store.dispatch('inboxes/get');

  if (isEditing.value) {
    if (!botFlows.value.length) await store.dispatch('botFlows/get');
    const flow = store.getters['botFlows/getBotFlows'].find(
      f => String(f.id) === String(botFlowId.value)
    );
    if (flow) loadFlow(flow);
  } else {
    initNewFlow();
  }
});

let nextY = 260;
const addNode = option => {
  if (!option) return;
  pushHistory();
  const type = option.id;
  nodes.value = [
    ...nodes.value,
    {
      id: generateNodeId(type),
      type,
      position: { x: 360, y: nextY },
      data: getDefaultNodeData(type),
    },
  ];
  nextY += 140;
};

const organizeLayout = () => {
  pushHistory();
  nodes.value = autoLayoutPositions(nodes.value, edges.value);
};

const removeSelectedNode = () => {
  if (
    !selectedNode.value ||
    selectedNode.value.type === BOT_FLOW_NODE_TYPES.START
  )
    return;
  pushHistory();
  const id = selectedNode.value.id;
  nodes.value = nodes.value.filter(n => n.id !== id);
  edges.value = edges.value.filter(e => e.source !== id && e.target !== id);
  selectedNodeId.value = null;
};

const duplicateSelectedNode = () => {
  if (
    !selectedNode.value ||
    selectedNode.value.type === BOT_FLOW_NODE_TYPES.START
  )
    return;
  pushHistory();
  const original = selectedNode.value;
  const clone = {
    id: generateNodeId(original.type),
    type: original.type,
    position: { x: original.position.x + 40, y: original.position.y + 40 },
    data: structuredClone(original.data),
  };
  nodes.value = [...nodes.value, clone];
  selectedNodeId.value = clone.id;
};

// Deleta o bloco selecionado com a tecla Delete/Backspace - mas não quando o
// foco está num campo de texto (senão apagar uma letra apagaria o bloco).
const handleKeydown = event => {
  const target = event.target;
  const isEditingText =
    target.tagName === 'INPUT' ||
    target.tagName === 'TEXTAREA' ||
    target.isContentEditable;
  if (isEditingText) return;

  const isUndoKey =
    (event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z';
  if (isUndoKey) {
    event.preventDefault();
    if (event.shiftKey) {
      redo();
    } else {
      undo();
    }
    return;
  }

  if (event.key !== 'Delete' && event.key !== 'Backspace') return;
  if (!selectedNode.value) return;

  event.preventDefault();
  removeSelectedNode();
};

onMounted(() => window.addEventListener('keydown', handleKeydown));
onUnmounted(() => window.removeEventListener('keydown', handleKeydown));

const validationError = computed(() => {
  if (!name.value.trim()) return t('BOT_FLOW.EDITOR.VALIDATION.NAME_REQUIRED');
  if (
    nodes.value.filter(n => n.type === BOT_FLOW_NODE_TYPES.START).length !== 1
  ) {
    return t('BOT_FLOW.EDITOR.VALIDATION.SINGLE_START');
  }
  if (nodes.value.some(node => !isNodeValid(node))) {
    return t('BOT_FLOW.EDITOR.VALIDATION.MISSING_FIELDS');
  }
  return null;
});

const saveFlow = async () => {
  if (validationError.value) {
    useAlert(validationError.value);
    return;
  }

  const payload = {
    name: name.value,
    description: description.value,
    active: active.value,
    trigger_type: triggerType.value,
    trigger_config:
      triggerType.value === 'keyword'
        ? {
            keywords: keywordsText.value
              .split(',')
              .map(k => k.trim())
              .filter(Boolean),
          }
        : {},
    inbox_ids: selectedInboxes.value.map(inbox => inbox.id),
    nodes: nodes.value.map(flowNodeToBackend),
    edges: edges.value.map(flowEdgeToBackend),
  };

  try {
    isSaving.value = true;
    if (isEditing.value) {
      await store.dispatch('botFlows/update', {
        id: botFlowId.value,
        ...payload,
      });
    } else {
      await store.dispatch('botFlows/create', payload);
    }
    useAlert(t('BOT_FLOW.EDITOR.SUCCESS_MESSAGE'));
    router.push({ name: 'bot_flows_list' });
  } catch (error) {
    useAlert(t('BOT_FLOW.EDITOR.ERROR_MESSAGE'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-[calc(100vh-7rem)]">
    <div class="flex flex-wrap items-end gap-4 p-4 border-b border-n-weak">
      <WithLabel
        :label="t('BOT_FLOW.EDITOR.NAME_LABEL')"
        name="name"
        class="w-64"
      >
        <NextInput
          v-model="name"
          :placeholder="t('BOT_FLOW.EDITOR.NAME_PLACEHOLDER')"
        />
      </WithLabel>

      <WithLabel
        :label="t('BOT_FLOW.EDITOR.TRIGGER_LABEL')"
        name="trigger_type"
        class="w-64"
      >
        <SingleSelect
          v-model="triggerTypeModel"
          :options="triggerTypeOptions"
          disable-search
          disable-deselect
        />
      </WithLabel>

      <WithLabel
        v-if="triggerType === 'keyword'"
        :label="t('BOT_FLOW.EDITOR.KEYWORDS_LABEL')"
        name="keywords"
        class="w-64"
      >
        <NextInput
          v-model="keywordsText"
          :placeholder="t('BOT_FLOW.EDITOR.KEYWORDS_PLACEHOLDER')"
        />
      </WithLabel>

      <WithLabel
        :label="t('BOT_FLOW.EDITOR.INBOXES_LABEL')"
        name="inbox_ids"
        class="w-64"
      >
        <MultiSelect
          v-model="selectedInboxes"
          :options="whatsappInboxOptions"
        />
      </WithLabel>

      <div class="ms-auto flex items-center gap-2">
        <SingleSelect
          :model-value="null"
          :options="addNodeOptions"
          :placeholder="t('BOT_FLOW.EDITOR.ADD_NODE')"
          placeholder-trailing-icon
          disable-deselect
          @update:model-value="addNode"
        />
        <NextButton
          v-tooltip.top="t('BOT_FLOW.EDITOR.UNDO')"
          icon="i-lucide-undo-2"
          slate
          ghost
          :disabled="!undoStack.length"
          @click="undo"
        />
        <NextButton
          v-tooltip.top="t('BOT_FLOW.EDITOR.REDO')"
          icon="i-lucide-redo-2"
          slate
          ghost
          :disabled="!redoStack.length"
          @click="redo"
        />
        <NextButton
          icon="i-lucide-layout-grid"
          slate
          faded
          :label="t('BOT_FLOW.EDITOR.ORGANIZE_LAYOUT')"
          @click="organizeLayout"
        />
        <NextButton
          :label="t('BOT_FLOW.EDITOR.SAVE')"
          :is-loading="isSaving"
          @click="saveFlow"
        />
      </div>
    </div>

    <div class="flex flex-1 min-h-0">
      <div class="flex-1 min-w-0">
        <Canvas
          v-model:nodes="nodes"
          v-model:edges="edges"
          :selected-node-id="selectedNodeId"
          @select-node="id => (selectedNodeId = id)"
          @before-change="pushHistory"
        />
      </div>
      <PropertyPanel
        v-if="selectedNode"
        :node="selectedNode"
        :nodes="nodes"
        :edges="edges"
        :is-start="selectedNode.type === BOT_FLOW_NODE_TYPES.START"
        @close="selectedNodeId = null"
        @remove="removeSelectedNode"
        @duplicate="duplicateSelectedNode"
      />
    </div>
  </div>
</template>
