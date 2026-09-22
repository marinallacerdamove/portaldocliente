<script setup>
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import InspectorSection from '../components/InspectorSection.vue';
import VariableTextArea from '../components/variables/VariableTextArea.vue';

defineProps({
  entries: { type: Array, default: () => [] },
  recentIds: { type: Array, default: () => [] },
  recordUsage: { type: Function, default: () => {} },
});

const modelValue = defineModel({ type: Object, required: true });
const { t } = useI18n();
</script>

<template>
  <InspectorSection :title="t('BOT_FLOW.EDITOR.PANEL.SECTIONS.MESSAGE')">
    <WithLabel
      :label="t('BOT_FLOW.EDITOR.PANEL.SEND_MESSAGE.TEXT_LABEL')"
      name="text"
      required
    >
      <VariableTextArea
        v-model="modelValue.text"
        :rows="6"
        :entries="entries"
        :recent-ids="recentIds"
        :record-usage="recordUsage"
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
  </InspectorSection>
</template>
