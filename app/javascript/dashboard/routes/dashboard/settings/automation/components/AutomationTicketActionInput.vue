<script setup>
// PATCH LOCAL (fork) - campos das ações de ticket da automação (gatilhos do
// Movidesk), que o AutomationActionInput não conhece:
// - custom_attribute (set_custom_attribute): [chave, valor], igual à macro;
// - text (set_subject): [assunto com variáveis];
// - notify_agents: [ids dos agentes (ou 'creator'), texto da nota interna].
// O action_params já sai daqui no formato que o backend grava.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import CustomAttributeActionInput from 'dashboard/components/widgets/CustomAttributeActionInput.vue';
import MacroVariablesMenu from 'dashboard/routes/dashboard/settings/macros/MacroVariablesMenu.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import MultiSelect from 'dashboard/components-next/filter/inputs/MultiSelect.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  inputType: { type: String, required: true },
  options: { type: Array, default: () => [] },
});

const params = defineModel({ type: Array, default: () => [] });

const { t } = useI18n();

const subject = computed({
  get: () => params.value?.[0] || '',
  set: value => {
    params.value = [value];
  },
});

const insertIntoSubject = token => {
  subject.value = [subject.value.trimEnd(), token].filter(Boolean).join(' ');
};

const agentIds = computed(() => params.value?.[0] || []);
const noteText = computed({
  get: () => params.value?.[1] || '',
  set: text => {
    params.value = [agentIds.value, text];
  },
});
const selectedAgents = computed({
  get: () => props.options.filter(option => agentIds.value.includes(option.id)),
  set: agents => {
    params.value = [agents.map(agent => agent.id), noteText.value];
  },
});

// Menu "Variáveis" da nota: entra onde está o cursor (updateSelectionWith).
const pendingVariable = ref('');
const insertIntoNote = token => {
  pendingVariable.value = token;
};
</script>

<template>
  <CustomAttributeActionInput
    v-if="inputType === 'custom_attribute'"
    v-model="params"
  />

  <div v-else-if="inputType === 'text'" class="flex items-center gap-2">
    <Input
      v-model="subject"
      size="sm"
      class="flex-1"
      :placeholder="t('MACROS.EDITOR.SUBJECT_PLACEHOLDER')"
    />
    <MacroVariablesMenu @insert="insertIntoSubject" />
  </div>

  <div v-else-if="inputType === 'notify_agents'" class="flex flex-col gap-2">
    <div class="flex flex-wrap items-center gap-2">
      <span class="text-xs text-n-slate-11">
        {{ t('AUTOMATION.ACTION.NOTIFY_AGENTS.AGENTS') }}
      </span>
      <MultiSelect
        v-model="selectedAgents"
        :options="options"
        dropdown-max-height="max-h-72"
      />
      <MacroVariablesMenu
        class="ltr:ml-auto rtl:mr-auto"
        @insert="insertIntoNote"
      />
    </div>
    <WootMessageEditor
      v-model="noteText"
      is-private
      :focus-on-mount="false"
      enable-variables
      :update-selection-with="pendingVariable"
      :enable-canned-responses="false"
      :placeholder="t('AUTOMATION.ACTION.NOTIFY_AGENTS.PLACEHOLDER')"
      class="[&_.ProseMirror-menubar]:hidden px-3 py-1 bg-n-alpha-1 rounded-lg outline outline-1 outline-n-weak dark:outline-n-strong"
      @clear-selection="pendingVariable = ''"
    />
    <p class="mb-0 text-xs text-n-slate-10">
      {{ t('AUTOMATION.ACTION.NOTIFY_AGENTS.HINT') }}
    </p>
  </div>
</template>
