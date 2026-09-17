<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  variableOptions: { type: Array, default: () => [] },
});

const modelValue = defineModel({ type: Object, required: true });
const { t } = useI18n();

const patternOptions = computed(() =>
  ['cnpj', 'cpf', 'email', 'telefone', 'personalizado'].map(id => ({
    id,
    name: t(
      `BOT_FLOW.EDITOR.PANEL.EXTRACT_PATTERN.PATTERNS.${id.toUpperCase()}`
    ),
  }))
);

const sourceVariableModel = computed({
  get: () =>
    props.variableOptions.find(
      o => o.id === modelValue.value.source_variable
    ) || null,
  set: option => {
    modelValue.value.source_variable = option?.id || '';
  },
});

const patternModel = computed({
  get: () =>
    patternOptions.value.find(o => o.id === modelValue.value.pattern) ||
    patternOptions.value[0],
  set: option => {
    modelValue.value.pattern = option?.id || 'cnpj';
  },
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <WithLabel
      :label="t('BOT_FLOW.EDITOR.PANEL.EXTRACT_PATTERN.SOURCE_VARIABLE_LABEL')"
      name="source_variable"
    >
      <SingleSelect v-model="sourceVariableModel" :options="variableOptions" />
    </WithLabel>

    <WithLabel
      :label="t('BOT_FLOW.EDITOR.PANEL.EXTRACT_PATTERN.PATTERN_LABEL')"
      name="pattern"
    >
      <SingleSelect
        v-model="patternModel"
        :options="patternOptions"
        disable-search
      />
    </WithLabel>

    <WithLabel
      v-if="modelValue.pattern === 'personalizado'"
      :label="t('BOT_FLOW.EDITOR.PANEL.EXTRACT_PATTERN.CUSTOM_PATTERN_LABEL')"
      name="custom_pattern"
    >
      <NextInput
        v-model="modelValue.custom_pattern"
        :placeholder="
          t('BOT_FLOW.EDITOR.PANEL.EXTRACT_PATTERN.CUSTOM_PATTERN_PLACEHOLDER')
        "
      />
    </WithLabel>

    <WithLabel
      :label="t('BOT_FLOW.EDITOR.PANEL.EXTRACT_PATTERN.TARGET_VARIABLE_LABEL')"
      name="target_variable"
    >
      <NextInput
        v-model="modelValue.target_variable"
        :placeholder="
          t('BOT_FLOW.EDITOR.PANEL.EXTRACT_PATTERN.TARGET_VARIABLE_PLACEHOLDER')
        "
      />
    </WithLabel>
  </div>
</template>
