<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import VariablePicker from './VariablePicker.vue';
import VariablePreview from './VariablePreview.vue';

const props = defineProps({
  placeholder: { type: String, default: '' },
  entries: { type: Array, default: () => [] },
  recentIds: { type: Array, default: () => [] },
  recordUsage: { type: Function, default: () => {} },
  priorityTypes: { type: Array, default: null },
});

const modelValue = defineModel({ type: String, default: '' });
const { t } = useI18n();

const triggerRef = ref(null);
const pickerOpen = ref(false);

const selectedEntry = computed(
  () => props.entries.find(entry => entry.id === modelValue.value) || null
);
const isStale = computed(() => !!modelValue.value && !selectedEntry.value);

const select = entry => {
  modelValue.value = entry.id;
  props.recordUsage(entry.id);
};
</script>

<template>
  <div class="flex flex-col gap-1 items-start">
    <button
      ref="triggerRef"
      type="button"
      class="inline-flex items-center gap-2 max-w-full h-8 px-2.5 rounded-lg text-sm bg-n-slate-9/10 hover:bg-n-slate-9/20 text-n-slate-12"
      :class="{ 'text-n-amber-11': isStale }"
      @click="pickerOpen = true"
    >
      <Icon
        :icon="
          isStale
            ? 'i-lucide-alert-triangle'
            : selectedEntry?.icon || 'i-lucide-list-filter'
        "
        class="size-3.5 shrink-0"
      />
      <span class="truncate">
        <template v-if="selectedEntry">{{ selectedEntry.label }}</template>
        <template v-else-if="isStale">{{ modelValue }}</template>
        <template v-else>
          {{
            placeholder ||
            t('BOT_FLOW.EDITOR.VARIABLE_PICKER.SELECT_PLACEHOLDER')
          }}
        </template>
      </span>
      <Icon icon="i-lucide-chevron-down" class="size-3.5 shrink-0 ms-auto" />
    </button>

    <p v-if="isStale" class="text-xs text-n-amber-11">
      {{ t('BOT_FLOW.EDITOR.WARNINGS.STALE_REFERENCE', { label: modelValue }) }}
    </p>
    <VariablePreview v-else-if="selectedEntry" :entry="selectedEntry" />

    <VariablePicker
      v-model:open="pickerOpen"
      :anchor-el="triggerRef"
      :entries="entries"
      :recent-ids="recentIds"
      :priority-types="priorityTypes"
      @select="select"
    />
  </div>
</template>
