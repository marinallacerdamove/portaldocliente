<script setup>
// PATCH LOCAL (fork) - uma ação da macro, em cartão (substitui o MacroNode do
// fluxo em nós). O seletor de tipo e os campos padrão vêm do
// AutomationActionInput; "Texto da resposta", "Assunto" e "Alterar campo do
// ticket" têm campos próprios.
import { computed, inject, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMacros } from 'dashboard/composables/useMacros';
import MacroVariablesMenu from './MacroVariablesMenu.vue';
import ActionInput from 'dashboard/components/widgets/AutomationActionInput.vue';
import CustomAttributeActionInput from 'dashboard/components/widgets/CustomAttributeActionInput.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { FILL_REPLY_MODES } from './constants';

const props = defineProps({
  index: { type: Number, required: true },
  errorKey: { type: String, default: '' },
  fileName: { type: String, default: '' },
  canRemove: { type: Boolean, default: true },
});

const emit = defineEmits(['resetAction', 'remove']);

const action = defineModel({ type: Object, required: true });

const { t } = useI18n();
const macroActionTypes = inject('macroActionTypes');
const { getMacroDropdownValues } = useMacros();

const CUSTOM_INPUTS = ['fill_reply', 'text', 'custom_attribute'];

const inputType = computed(
  () =>
    macroActionTypes.value.find(type => type.key === action.value.action_name)
      ?.inputType
);

const errorMessage = computed(() =>
  props.errorKey ? t(`MACROS.ERRORS.${props.errorKey}`) : ''
);

// Altera a própria ação (sem trocar o objeto): trocar recriaria o cartão
// (a chave do arrastar-e-soltar é o objeto) e o editor perderia o foco a
// cada letra.
const updateParams = params => {
  action.value.action_params = params;
};

const fillMode = computed(
  () => action.value.action_params?.[1] || FILL_REPLY_MODES.REPLY
);

const fillContent = computed({
  get: () => action.value.action_params?.[0] || '',
  set: content => updateParams([content, fillMode.value]),
});

const setFillMode = mode => updateParams([fillContent.value, mode]);

const subject = computed({
  get: () => action.value.action_params?.[0] || '',
  set: value => updateParams([value]),
});

// Menu "Variáveis": no editor entra onde está o cursor (updateSelectionWith do
// WootMessageEditor); no assunto, no fim do texto.
const pendingVariable = ref('');
const insertIntoReply = token => {
  pendingVariable.value = token;
};
const insertIntoSubject = token => {
  subject.value = [subject.value.trimEnd(), token].filter(Boolean).join(' ');
};

const FILL_MODE_OPTIONS = [
  {
    mode: FILL_REPLY_MODES.REPLY,
    label: 'MACROS.EDITOR.FILL_REPLY.REPLY',
    icon: 'i-lucide-reply',
  },
  {
    mode: FILL_REPLY_MODES.NOTE,
    label: 'MACROS.EDITOR.FILL_REPLY.NOTE',
    icon: 'i-lucide-lock',
  },
];
</script>

<template>
  <div
    class="flex gap-3 p-3 border rounded-lg bg-n-alpha-1"
    :class="errorKey ? 'border-n-ruby-7' : 'border-n-weak'"
  >
    <div class="flex flex-col items-center gap-1 pt-1.5 shrink-0">
      <span
        class="flex items-center justify-center text-xs font-medium rounded-full size-6 bg-n-alpha-2 text-n-slate-11"
      >
        {{ index + 1 }}
      </span>
      <Button
        v-tooltip.top="t('MACROS.EDITOR.DRAG_TOOLTIP')"
        icon="i-lucide-grip-vertical"
        ghost
        slate
        xs
        class="cursor-move macro-action-drag-handle"
      />
    </div>

    <div class="flex flex-col flex-1 min-w-0 gap-3">
      <ActionInput
        v-model="action"
        :action-types="macroActionTypes"
        :dropdown-values="getMacroDropdownValues(action.action_name)"
        :show-action-input="!!inputType && !CUSTOM_INPUTS.includes(inputType)"
        :initial-file-name="fileName"
        is-macro
        :error-message="errorMessage"
        @reset-action="emit('resetAction')"
      />

      <template v-if="inputType === 'fill_reply'">
        <div class="flex flex-wrap items-center gap-2">
          <MacroVariablesMenu
            class="ltr:ml-auto rtl:mr-auto order-last"
            @insert="insertIntoReply"
          />
          <Button
            v-for="option in FILL_MODE_OPTIONS"
            :key="option.mode"
            :label="t(option.label)"
            :icon="option.icon"
            xs
            :color="fillMode === option.mode ? 'blue' : 'slate'"
            :variant="fillMode === option.mode ? 'faded' : 'ghost'"
            @click="setFillMode(option.mode)"
          />
        </div>
        <WootMessageEditor
          v-model="fillContent"
          :is-private="fillMode === FILL_REPLY_MODES.NOTE"
          :focus-on-mount="false"
          override-line-breaks
          enable-variables
          enable-tables
          :update-selection-with="pendingVariable"
          :enable-canned-responses="false"
          :placeholder="t('MACROS.EDITOR.FILL_REPLY.PLACEHOLDER')"
          class="px-3 py-1 rounded-lg bg-n-solid-1 outline outline-1 outline-n-weak dark:outline-n-strong"
          @clear-selection="pendingVariable = ''"
        />
        <p class="mb-0 text-xs text-n-slate-10">
          {{ t('MACROS.EDITOR.FILL_REPLY.HINT') }}
        </p>
      </template>

      <div v-else-if="inputType === 'text'" class="flex items-center gap-2">
        <Input
          v-model="subject"
          size="sm"
          class="flex-1"
          :placeholder="t('MACROS.EDITOR.SUBJECT_PLACEHOLDER')"
        />
        <MacroVariablesMenu @insert="insertIntoSubject" />
      </div>

      <CustomAttributeActionInput
        v-else-if="inputType === 'custom_attribute'"
        v-model="action.action_params"
      />
    </div>

    <Button
      v-if="canRemove"
      v-tooltip.top="t('MACROS.EDITOR.DELETE_BTN_TOOLTIP')"
      icon="i-lucide-trash-2"
      ghost
      ruby
      xs
      class="shrink-0"
      @click="emit('remove')"
    />
  </div>
</template>
