<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { Handle, Position } from '@vue-flow/core';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  BOT_FLOW_NODE_TYPES,
  handlesForNode,
  isNodeValid,
} from 'dashboard/helper/botFlowHelper';

const props = defineProps({
  type: { type: String, required: true },
  data: { type: Object, default: () => ({}) },
  selected: { type: Boolean, default: false },
});

const { t } = useI18n();

const ICONS = {
  [BOT_FLOW_NODE_TYPES.START]: 'i-lucide-play',
  [BOT_FLOW_NODE_TYPES.SEND_MESSAGE]: 'i-lucide-message-square',
  [BOT_FLOW_NODE_TYPES.MENU]: 'i-lucide-list',
  [BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT]: 'i-lucide-help-circle',
  [BOT_FLOW_NODE_TYPES.CONDITION]: 'i-lucide-split',
  [BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN]: 'i-lucide-regex',
  [BOT_FLOW_NODE_TYPES.WEBHOOK]: 'i-lucide-globe',
  [BOT_FLOW_NODE_TYPES.CHATWOOT_ACTION]: 'i-lucide-zap',
  [BOT_FLOW_NODE_TYPES.CNPJ_LOOKUP]: 'i-lucide-building-2',
  [BOT_FLOW_NODE_TYPES.RECEITA_CNPJ_LOOKUP]: 'i-lucide-landmark',
};

const icon = computed(() => ICONS[props.type] || 'i-lucide-box');
const title = computed(() =>
  t(`BOT_FLOW.EDITOR.NODE_TYPES.${props.type.toUpperCase()}`)
);

const summary = computed(() => {
  const data = props.data || {};
  switch (props.type) {
    case BOT_FLOW_NODE_TYPES.SEND_MESSAGE:
      return data.private
        ? `${t('BOT_FLOW.EDITOR.NODE_SUMMARY.PRIVATE_PREFIX')} ${data.text || ''}`
        : data.text;
    case BOT_FLOW_NODE_TYPES.MENU:
      return data.prompt;
    case BOT_FLOW_NODE_TYPES.ASK_AND_EXTRACT:
      return data.prompt;
    case BOT_FLOW_NODE_TYPES.CONDITION:
      return (data.branches || []).length
        ? t('BOT_FLOW.EDITOR.NODE_SUMMARY.CONDITION_PATHS', {
            n: data.branches.length,
          })
        : '';
    case BOT_FLOW_NODE_TYPES.EXTRACT_PATTERN:
      return data.source_variable
        ? `{{${data.source_variable}}} → {{${data.target_variable || '?'}}}`
        : '';
    case BOT_FLOW_NODE_TYPES.WEBHOOK:
      return data.url;
    case BOT_FLOW_NODE_TYPES.CHATWOOT_ACTION:
      return data.action_name
        ? t(
            `BOT_FLOW.EDITOR.PANEL.CHATWOOT_ACTION.ACTIONS.${data.action_name.toUpperCase()}`
          )
        : '';
    case BOT_FLOW_NODE_TYPES.CNPJ_LOOKUP:
      return data.source_variable
        ? `{{${data.source_variable}}} → {{empresa_nome}}`
        : '';
    case BOT_FLOW_NODE_TYPES.RECEITA_CNPJ_LOOKUP:
      return data.source_variable
        ? `{{${data.source_variable}}} → {{empresa_razao_social}}...`
        : '';
    default:
      return '';
  }
});

// Rótulo mostrado ao lado de cada saída (handle) - vem de options/rules
// quando dinâmico (Menu/Condição), ou de um texto fixo pros demais tipos.
const outputRows = computed(() => {
  const data = props.data || {};
  if (props.type === BOT_FLOW_NODE_TYPES.MENU) {
    return (data.options || []).map(option => ({
      handle: `option-${option.id}`,
      label: option.label,
    }));
  }
  if (props.type === BOT_FLOW_NODE_TYPES.CONDITION) {
    return [
      ...(data.branches || []).map((branch, index) => ({
        handle: `branch-${branch.id}`,
        label: t('BOT_FLOW.EDITOR.PANEL.CONDITION.BRANCH_LABEL', {
          n: index + 1,
        }),
      })),
      { handle: 'else', label: t('BOT_FLOW.EDITOR.HANDLES.ELSE') },
    ];
  }
  return handlesForNode({ type: props.type, data }).map(handle => ({
    handle,
    label: t(`BOT_FLOW.EDITOR.HANDLES.${handle.toUpperCase()}`),
  }));
});

const invalid = computed(
  () => !isNodeValid({ type: props.type, data: props.data })
);
</script>

<template>
  <div
    class="min-w-[220px] max-w-[280px] rounded-lg border bg-n-solid-1 shadow-sm"
    :class="selected ? 'border-n-brand ring-1 ring-n-brand' : 'border-n-weak'"
  >
    <Handle
      v-if="type !== 'start'"
      type="target"
      :position="Position.Left"
      class="!size-3.5"
    />

    <div class="flex items-center gap-2 px-3 py-2 border-b border-n-weak">
      <Icon :icon="icon" class="size-4 text-n-slate-11 flex-shrink-0" />
      <span class="text-sm font-medium text-n-slate-12 truncate">{{
        title
      }}</span>
      <Icon
        v-if="invalid"
        v-tooltip.top="t('BOT_FLOW.EDITOR.VALIDATION.MISSING_FIELDS')"
        icon="i-lucide-alert-triangle"
        class="size-3.5 text-n-amber-9 ms-auto flex-shrink-0"
      />
    </div>

    <div v-if="summary" class="px-3 py-2 text-xs text-n-slate-11 truncate">
      {{ summary }}
    </div>

    <div v-if="outputRows.length" class="flex flex-col gap-1.5 px-3 py-2">
      <div
        v-for="row in outputRows"
        :key="row.handle"
        class="relative flex items-center justify-between gap-2 text-xs text-n-slate-11"
      >
        <span class="truncate">{{ row.label }}</span>
        <Handle
          :id="row.handle"
          type="source"
          :position="Position.Right"
          class="!static !size-3.5 !translate-x-0 !translate-y-0 !ms-2"
        />
      </div>
    </div>
  </div>
</template>
