<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import { slugifyVariableName } from 'dashboard/helper/botFlowHelper';
import InspectorSection from '../components/InspectorSection.vue';
import VariableSelect from '../components/variables/VariableSelect.vue';

defineProps({
  entries: { type: Array, default: () => [] },
  recentIds: { type: Array, default: () => [] },
  recordUsage: { type: Function, default: () => {} },
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

const patternModel = computed({
  get: () =>
    patternOptions.value.find(o => o.id === modelValue.value.pattern) ||
    patternOptions.value[0],
  set: option => {
    modelValue.value.pattern = option?.id || 'cnpj';
  },
});

watch(
  () => modelValue.value.target_variable_label,
  label => {
    modelValue.value.target_variable = slugifyVariableName(label);
  }
);

// Montado no script (não no template) porque colocar "{{"/"}}" literais
// dentro de uma interpolação {{ }} do próprio Vue quebra o parser do template.
const variablePreview = computed(() =>
  t('BOT_FLOW.EDITOR.PANEL.ASK_AND_EXTRACT.VARIABLE_PREVIEW', {
    token: `{{${modelValue.value.target_variable}}}`,
  })
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <InspectorSection :title="t('BOT_FLOW.EDITOR.PANEL.SECTIONS.SOURCE')">
      <WithLabel
        :label="
          t('BOT_FLOW.EDITOR.PANEL.EXTRACT_PATTERN.SOURCE_VARIABLE_LABEL')
        "
        name="source_variable"
        required
      >
        <VariableSelect
          v-model="modelValue.source_variable"
          :entries="entries"
          :recent-ids="recentIds"
          :record-usage="recordUsage"
        />
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
        :help-message="
          t('BOT_FLOW.EDITOR.PANEL.EXTRACT_PATTERN.CUSTOM_PATTERN_HELP')
        "
        name="custom_pattern"
      >
        <NextInput
          v-model="modelValue.custom_pattern"
          :placeholder="
            t(
              'BOT_FLOW.EDITOR.PANEL.EXTRACT_PATTERN.CUSTOM_PATTERN_PLACEHOLDER'
            )
          "
        />
      </WithLabel>
    </InspectorSection>

    <InspectorSection
      :title="t('BOT_FLOW.EDITOR.PANEL.SECTIONS.SAVE_RESPONSE')"
    >
      <WithLabel
        :label="
          t('BOT_FLOW.EDITOR.PANEL.EXTRACT_PATTERN.TARGET_VARIABLE_LABEL')
        "
        name="target_variable_label"
        required
      >
        <NextInput
          v-model="modelValue.target_variable_label"
          :placeholder="
            t(
              'BOT_FLOW.EDITOR.PANEL.EXTRACT_PATTERN.TARGET_VARIABLE_PLACEHOLDER'
            )
          "
        />
      </WithLabel>
      <p
        v-if="modelValue.target_variable"
        class="text-xs text-n-slate-10 -mt-2"
      >
        {{ variablePreview }}
      </p>
    </InspectorSection>
  </div>
</template>
