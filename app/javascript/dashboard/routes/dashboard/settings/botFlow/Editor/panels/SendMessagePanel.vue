<script setup>
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import VariableAwareTextField from '../components/VariableAwareTextField.vue';

defineProps({
  variableOptions: { type: Array, default: () => [] },
});

const modelValue = defineModel({ type: Object, required: true });
const { t } = useI18n();
</script>

<template>
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
</template>
