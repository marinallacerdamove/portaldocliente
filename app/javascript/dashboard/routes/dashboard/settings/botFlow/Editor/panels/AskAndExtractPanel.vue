<script setup>
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
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
      :label="t('BOT_FLOW.EDITOR.PANEL.ASK_AND_EXTRACT.PROMPT_LABEL')"
      name="prompt"
    >
      <VariableAwareTextField
        v-model="modelValue.prompt"
        :variable-options="variableOptions"
        :placeholder="
          t('BOT_FLOW.EDITOR.PANEL.ASK_AND_EXTRACT.PROMPT_PLACEHOLDER')
        "
      />
    </WithLabel>
    <WithLabel
      :label="t('BOT_FLOW.EDITOR.PANEL.ASK_AND_EXTRACT.VARIABLE_NAME_LABEL')"
      :help-message="
        t('BOT_FLOW.EDITOR.PANEL.ASK_AND_EXTRACT.VARIABLE_NAME_HELP')
      "
      name="variable_name"
    >
      <NextInput
        v-model="modelValue.variable_name"
        :placeholder="
          t('BOT_FLOW.EDITOR.PANEL.ASK_AND_EXTRACT.VARIABLE_NAME_PLACEHOLDER')
        "
      />
    </WithLabel>
  </div>
</template>
