<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useBotFlowVariables } from 'dashboard/composables/useBotFlowVariables';
import { BOT_FLOW_NODE_TYPES } from 'dashboard/helper/botFlowHelper';
import SendMessagePanel from './panels/SendMessagePanel.vue';
import MenuPanel from './panels/MenuPanel.vue';
import AskAndExtractPanel from './panels/AskAndExtractPanel.vue';
import ConditionPanel from './panels/ConditionPanel.vue';
import ExtractPatternPanel from './panels/ExtractPatternPanel.vue';
import WebhookPanel from './panels/WebhookPanel.vue';
import ChatwootActionPanel from './panels/ChatwootActionPanel.vue';
import CnpjLookupPanel from './panels/CnpjLookupPanel.vue';

const props = defineProps({
  node: { type: Object, required: true },
  nodes: { type: Array, required: true },
  edges: { type: Array, required: true },
  isStart: { type: Boolean, default: false },
});
const emit = defineEmits(['close', 'remove', 'duplicate']);

const { t } = useI18n();

const PANELS = {
  [BOT_FLOW_NODE_TYPES.SEND_MESSAGE]: SendMessagePanel,
  [BOT_FLOW_NODE_TYPES.MENU]: MenuPanel,
  [BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT]: AskAndExtractPanel,
  [BOT_FLOW_NODE_TYPES.CONDITION]: ConditionPanel,
  [BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN]: ExtractPatternPanel,
  [BOT_FLOW_NODE_TYPES.WEBHOOK]: WebhookPanel,
  [BOT_FLOW_NODE_TYPES.CHATWOOT_ACTION]: ChatwootActionPanel,
  [BOT_FLOW_NODE_TYPES.CNPJ_LOOKUP]: CnpjLookupPanel,
};

const panelComponent = computed(() => PANELS[props.node.type]);
const title = computed(() =>
  t(`BOT_FLOW.EDITOR.NODE_TYPES.${props.node.type.toUpperCase()}`)
);

const { variableOptions, insertableVariableOptions } = useBotFlowVariables(
  () => props.nodes,
  () => props.edges,
  () => props.node.id
);

// Condição/Extrair padrão comparam uma variável capturada diretamente - só
// essas fazem sentido ali. Os demais tipos usam texto livre com {{...}}, aí
// as variáveis do sistema (nome/e-mail/telefone do contato) valem também.
const CAPTURED_ONLY_TYPES = [
  BOT_FLOW_NODE_TYPES.CONDITION,
  BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN,
  BOT_FLOW_NODE_TYPES.CNPJ_LOOKUP,
];
const panelVariableOptions = computed(() =>
  CAPTURED_ONLY_TYPES.includes(props.node.type)
    ? variableOptions.value
    : insertableVariableOptions.value
);
</script>

<template>
  <div
    class="flex flex-col gap-4 h-full overflow-y-auto p-4 w-80 border-s border-n-weak"
  >
    <div class="flex items-center justify-between">
      <h4 class="text-sm font-medium text-n-slate-12">{{ title }}</h4>
      <div class="flex items-center gap-1">
        <NextButton
          v-if="!isStart"
          v-tooltip.top="t('BOT_FLOW.EDITOR.DUPLICATE_NODE')"
          icon="i-lucide-copy"
          slate
          ghost
          sm
          @click="emit('duplicate')"
        />
        <NextButton
          v-if="!isStart"
          icon="i-lucide-trash-2"
          slate
          ghost
          sm
          @click="emit('remove')"
        />
        <NextButton icon="i-lucide-x" slate ghost sm @click="emit('close')" />
      </div>
    </div>

    <p v-if="isStart" class="text-sm text-n-slate-11">
      {{ t('BOT_FLOW.EDITOR.NODE_TYPES.START') }}
    </p>
    <component
      :is="panelComponent"
      v-else-if="panelComponent"
      :model-value="node.data"
      :variable-options="panelVariableOptions"
    />
  </div>
</template>
