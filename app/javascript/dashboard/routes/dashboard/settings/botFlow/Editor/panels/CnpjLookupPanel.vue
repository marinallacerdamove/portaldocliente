<script setup>
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import InspectorSection from '../components/InspectorSection.vue';
import VariableSelect from '../components/variables/VariableSelect.vue';

defineProps({
  entries: { type: Array, default: () => [] },
  recentIds: { type: Array, default: () => [] },
  recordUsage: { type: Function, default: () => {} },
});

const modelValue = defineModel({ type: Object, required: true });
const { t } = useI18n();

// Prioriza variáveis do tipo "documento" e texto capturado (a fonte real mais
// comum é a resposta livre de um "Pedir informação") - "Ver todas" continua
// disponível pra qualquer outro caso.
const PRIORITY_TYPES = ['document', 'string'];
</script>

<template>
  <div class="flex flex-col gap-4">
    <p class="text-xs text-n-slate-10 bg-n-slate-2 rounded-lg p-2">
      {{ t('BOT_FLOW.EDITOR.PANEL.CNPJ_LOOKUP.INTRO_HELP') }}
    </p>

    <InspectorSection :title="t('BOT_FLOW.EDITOR.PANEL.SECTIONS.SOURCE')">
      <WithLabel
        :label="t('BOT_FLOW.EDITOR.PANEL.CNPJ_LOOKUP.SOURCE_VARIABLE_LABEL')"
        name="source_variable"
        required
      >
        <VariableSelect
          v-model="modelValue.source_variable"
          :entries="entries"
          :recent-ids="recentIds"
          :record-usage="recordUsage"
          :priority-types="PRIORITY_TYPES"
        />
      </WithLabel>
    </InspectorSection>
  </div>
</template>
