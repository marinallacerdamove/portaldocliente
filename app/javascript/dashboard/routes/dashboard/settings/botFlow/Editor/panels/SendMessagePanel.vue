<script setup>
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';

const modelValue = defineModel({ type: Object, required: true });
const { t } = useI18n();
</script>

<template>
  <WithLabel
    :label="t('BOT_FLOW.EDITOR.PANEL.SEND_MESSAGE.TEXT_LABEL')"
    name="text"
  >
    <textarea
      v-model="modelValue.text"
      rows="4"
      class="w-full reset-base rounded-lg border border-n-weak bg-n-solid-1 p-2 text-sm"
      :placeholder="t('BOT_FLOW.EDITOR.PANEL.SEND_MESSAGE.TEXT_PLACEHOLDER')"
    />
  </WithLabel>
</template>
