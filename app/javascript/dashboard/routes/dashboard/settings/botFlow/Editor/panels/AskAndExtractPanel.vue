<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import { slugifyVariableName } from 'dashboard/helper/botFlowHelper';
import InspectorSection from '../components/InspectorSection.vue';
import VariableTextArea from '../components/variables/VariableTextArea.vue';

defineProps({
  entries: { type: Array, default: () => [] },
  recentIds: { type: Array, default: () => [] },
  recordUsage: { type: Function, default: () => {} },
});

const modelValue = defineModel({ type: Object, required: true });
const { t } = useI18n();

// A pessoa só digita o nome amigável ("CNPJ do cliente") - o identificador
// técnico usado dentro de {{...}} é gerado sozinho a cada tecla, sem exigir
// entender o que é um slug.
watch(
  () => modelValue.value.variable_label,
  label => {
    modelValue.value.variable_name = slugifyVariableName(label);
  }
);

// Montado no script (não no template) porque colocar "{{"/"}}" literais
// dentro de uma interpolação {{ }} do próprio Vue quebra o parser do template.
const variablePreview = computed(() =>
  t('BOT_FLOW.EDITOR.PANEL.ASK_AND_EXTRACT.VARIABLE_PREVIEW', {
    token: `{{${modelValue.value.variable_name}}}`,
  })
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <InspectorSection :title="t('BOT_FLOW.EDITOR.PANEL.SECTIONS.MESSAGE')">
      <WithLabel
        :label="t('BOT_FLOW.EDITOR.PANEL.ASK_AND_EXTRACT.PROMPT_LABEL')"
        name="prompt"
        required
      >
        <VariableTextArea
          v-model="modelValue.prompt"
          :rows="6"
          :entries="entries"
          :recent-ids="recentIds"
          :record-usage="recordUsage"
          :placeholder="
            t('BOT_FLOW.EDITOR.PANEL.ASK_AND_EXTRACT.PROMPT_PLACEHOLDER')
          "
        />
      </WithLabel>
    </InspectorSection>

    <InspectorSection
      :title="t('BOT_FLOW.EDITOR.PANEL.SECTIONS.SAVE_RESPONSE')"
    >
      <WithLabel
        :label="t('BOT_FLOW.EDITOR.PANEL.ASK_AND_EXTRACT.VARIABLE_LABEL_LABEL')"
        name="variable_label"
        required
      >
        <NextInput
          v-model="modelValue.variable_label"
          :placeholder="
            t(
              'BOT_FLOW.EDITOR.PANEL.ASK_AND_EXTRACT.VARIABLE_LABEL_PLACEHOLDER'
            )
          "
        />
      </WithLabel>
      <p v-if="modelValue.variable_name" class="text-xs text-n-slate-10 -mt-2">
        {{ variablePreview }}
      </p>
    </InspectorSection>
  </div>
</template>
