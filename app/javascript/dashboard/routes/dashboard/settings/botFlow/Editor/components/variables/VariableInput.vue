<script setup>
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useVariableAwareField } from '../../composables/useVariableAwareField';
import VariablePicker from './VariablePicker.vue';

const props = defineProps({
  placeholder: { type: String, default: '' },
  monospace: { type: Boolean, default: false },
  entries: { type: Array, default: () => [] },
  recentIds: { type: Array, default: () => [] },
  recordUsage: { type: Function, default: () => {} },
});

const modelValue = defineModel({ type: String, default: '' });
const { t } = useI18n();

const {
  fieldRef,
  pickerOpen,
  pickerQuery,
  handleInput,
  openPicker,
  insertAtCursor,
} = useVariableAwareField(modelValue);

const handleSelect = entry => {
  insertAtCursor(entry.id);
  props.recordUsage(entry.id);
};
</script>

<template>
  <div class="flex items-center gap-1.5">
    <input
      ref="fieldRef"
      v-model="modelValue"
      type="text"
      :placeholder="placeholder"
      class="w-full reset-base rounded-lg border border-n-weak bg-n-solid-1 p-2 text-sm h-9"
      :class="{ 'font-mono': monospace }"
      @input="handleInput"
    />
    <NextButton
      v-tooltip.top="t('BOT_FLOW.EDITOR.VARIABLE_PICKER.TRIGGER_LABEL')"
      type="button"
      icon="i-lucide-plus"
      slate
      ghost
      sm
      @click="openPicker"
    />
    <VariablePicker
      v-model:open="pickerOpen"
      :anchor-el="fieldRef"
      :entries="entries"
      :recent-ids="recentIds"
      :initial-query="pickerQuery"
      @select="handleSelect"
    />
  </div>
</template>
