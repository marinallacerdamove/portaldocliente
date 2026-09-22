<script setup>
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import InspectorSection from '../components/InspectorSection.vue';
import VariableTextArea from '../components/variables/VariableTextArea.vue';
import { generateOptionId } from 'dashboard/helper/botFlowHelper';

defineProps({
  entries: { type: Array, default: () => [] },
  recentIds: { type: Array, default: () => [] },
  recordUsage: { type: Function, default: () => {} },
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
  <div class="flex flex-col gap-6">
    <InspectorSection :title="t('BOT_FLOW.EDITOR.PANEL.SECTIONS.MESSAGE')">
      <WithLabel
        :label="t('BOT_FLOW.EDITOR.PANEL.MENU.PROMPT_LABEL')"
        name="prompt"
        required
      >
        <VariableTextArea
          v-model="modelValue.prompt"
          :entries="entries"
          :recent-ids="recentIds"
          :record-usage="recordUsage"
          :placeholder="t('BOT_FLOW.EDITOR.PANEL.MENU.PROMPT_PLACEHOLDER')"
        />
      </WithLabel>

      <WithLabel
        :label="t('BOT_FLOW.EDITOR.PANEL.MENU.RETRY_PROMPT_LABEL')"
        name="retry_prompt"
      >
        <VariableTextArea
          v-model="modelValue.retry_prompt"
          :entries="entries"
          :recent-ids="recentIds"
          :record-usage="recordUsage"
        />
      </WithLabel>
    </InspectorSection>

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
