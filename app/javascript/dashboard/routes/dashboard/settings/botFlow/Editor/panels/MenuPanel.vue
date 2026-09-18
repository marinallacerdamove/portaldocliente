<script setup>
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import VariableAwareTextField from '../components/VariableAwareTextField.vue';
import { generateOptionId } from 'dashboard/helper/botFlowHelper';

defineProps({
  variableOptions: { type: Array, default: () => [] },
});

const modelValue = defineModel({ type: Object, required: true });
const { t } = useI18n();

const addOption = () => {
  modelValue.value.options = [
    ...(modelValue.value.options || []),
    { id: generateOptionId(), label: '' },
  ];
};

const removeOption = index => {
  modelValue.value.options = modelValue.value.options.filter(
    (_, i) => i !== index
  );
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <WithLabel
      :label="t('BOT_FLOW.EDITOR.PANEL.MENU.PROMPT_LABEL')"
      name="prompt"
    >
      <VariableAwareTextField
        v-model="modelValue.prompt"
        :variable-options="variableOptions"
        :placeholder="t('BOT_FLOW.EDITOR.PANEL.MENU.PROMPT_PLACEHOLDER')"
      />
    </WithLabel>

    <WithLabel
      :label="t('BOT_FLOW.EDITOR.PANEL.MENU.RETRY_PROMPT_LABEL')"
      name="retry_prompt"
    >
      <VariableAwareTextField
        v-model="modelValue.retry_prompt"
        :variable-options="variableOptions"
      />
    </WithLabel>

    <div class="flex flex-col gap-2">
      <span class="text-sm font-medium text-n-slate-11">{{
        t('BOT_FLOW.EDITOR.PANEL.MENU.OPTIONS_LABEL')
      }}</span>
      <div
        v-for="(option, index) in modelValue.options || []"
        :key="option.id"
        class="flex items-center gap-2"
      >
        <NextInput
          v-model="option.label"
          class="flex-1"
          :placeholder="t('BOT_FLOW.EDITOR.PANEL.MENU.OPTION_PLACEHOLDER')"
        />
        <NextButton
          icon="i-lucide-trash-2"
          slate
          ghost
          sm
          @click="removeOption(index)"
        />
      </div>
      <NextButton
        sm
        slate
        faded
        icon="i-lucide-plus"
        :label="t('BOT_FLOW.EDITOR.PANEL.MENU.ADD_OPTION')"
        @click="addOption"
      />
    </div>
  </div>
</template>
