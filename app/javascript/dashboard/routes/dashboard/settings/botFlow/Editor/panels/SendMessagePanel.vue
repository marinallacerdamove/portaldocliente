<script setup>
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import VariableAwareTextField from '../components/VariableAwareTextField.vue';

defineProps({
  variableOptions: { type: Array, default: () => [] },
});

const modelValue = defineModel({ type: Object, required: true });
const { t } = useI18n();
</script>

<template>
  <div class="flex flex-col gap-4">
    <WithLabel
      :label="t('BOT_FLOW.EDITOR.PANEL.SEND_MESSAGE.TEXT_LABEL')"
      name="text"
    >
      <VariableAwareTextField
        v-model="modelValue.text"
        multiline
        :rows="4"
        :variable-options="variableOptions"
        :placeholder="t('BOT_FLOW.EDITOR.PANEL.SEND_MESSAGE.TEXT_PLACEHOLDER')"
      />
    </WithLabel>

    <label class="flex items-start gap-2.5 cursor-pointer select-none">
      <Switch v-model="modelValue.private" class="mt-0.5" />
      <span>
        <span class="block text-sm text-n-slate-12">
          {{ t('BOT_FLOW.EDITOR.PANEL.SEND_MESSAGE.PRIVATE_LABEL') }}
        </span>
        <span class="block text-xs text-n-slate-10">
          {{ t('BOT_FLOW.EDITOR.PANEL.SEND_MESSAGE.PRIVATE_HELP') }}
        </span>
      </span>
    </label>
  </div>
</template>
