<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';

const props = defineProps({
  variableOptions: { type: Array, default: () => [] },
});

const modelValue = defineModel({ type: Object, required: true });
const { t } = useI18n();

const sourceVariableModel = computed({
  get: () =>
    props.variableOptions.find(
      o => o.id === modelValue.value.source_variable
    ) || null,
  set: option => {
    modelValue.value.source_variable = option?.id || '';
  },
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <p class="text-xs text-n-slate-10 bg-n-slate-2 rounded-lg p-2">
      {{ t('BOT_FLOW.EDITOR.PANEL.CNPJ_LOOKUP.INTRO_HELP') }}
    </p>

    <WithLabel
      :label="t('BOT_FLOW.EDITOR.PANEL.CNPJ_LOOKUP.SOURCE_VARIABLE_LABEL')"
      :help-message="
        t('BOT_FLOW.EDITOR.PANEL.CNPJ_LOOKUP.SOURCE_VARIABLE_HELP')
      "
      name="source_variable"
    >
      <SingleSelect v-model="sourceVariableModel" :options="variableOptions" />
    </WithLabel>
  </div>
</template>
