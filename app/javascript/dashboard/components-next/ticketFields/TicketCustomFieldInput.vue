<script setup>
// PATCH LOCAL (fork) - o campo de um campo adicional (Movidesk: Campos
// adicionais) conforme o tipo, sem saber onde o valor é gravado: a lateral da
// conversa (TicketCustomFields.vue) grava na hora, o "Novo ticket interno"
// guarda no formulário. update:modelValue sai a cada mudança; commit sai quando
// o valor está pronto pra gravar (lista e caixas na hora, texto e data ao sair).
import { useI18n } from 'vue-i18n';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import {
  FIELD_SIZE,
  FIELD_INPUT_CLASS,
} from 'dashboard/constants/ticketFieldLayout';
import { CHECKLIST_FIELD_TYPE } from 'dashboard/helper/ticketFieldRules';

const props = defineProps({
  field: { type: Object, required: true },
  modelValue: { type: [String, Array], default: '' },
});
const emit = defineEmits(['update:modelValue', 'commit']);

const TEXTAREA_MAX_LENGTH = 5000;
const INPUT_TYPES = { text: 'text', date: 'date', datetime: 'datetime-local' };
const SELECT_TYPES = ['list', 'single_select'];
const CHECKBOX_TYPES = ['multi_select', CHECKLIST_FIELD_TYPE];

const { t } = useI18n();

const optionsOf = field =>
  field.options.map(option => ({ value: option, label: option }));

const change = (value, { commit = true } = {}) => {
  emit('update:modelValue', value);
  if (commit) emit('commit', value);
};

// Marcadas na ordem das opções do campo, igual o Movidesk mostra.
const toggleOption = (option, checked) => {
  const selected = new Set(
    Array.isArray(props.modelValue) ? props.modelValue : []
  );
  if (checked) selected.add(option);
  else selected.delete(option);
  change(props.field.options.filter(item => selected.has(item)));
};

const isChecked = option =>
  Array.isArray(props.modelValue) && props.modelValue.includes(option);
</script>

<template>
  <ComboBox
    v-if="SELECT_TYPES.includes(field.field_type)"
    :size="FIELD_SIZE"
    :model-value="modelValue || ''"
    :options="optionsOf(field)"
    :display-label="modelValue || ''"
    :placeholder="
      t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.SELECT_PLACEHOLDER')
    "
    @update:model-value="value => change(value)"
  />
  <div
    v-else-if="CHECKBOX_TYPES.includes(field.field_type)"
    class="flex flex-col gap-1.5"
  >
    <label
      v-for="option in field.options"
      :key="option"
      class="flex items-start gap-2 mb-0 text-xs cursor-pointer text-n-slate-12"
    >
      <Checkbox
        class="mt-0.5 shrink-0"
        :model-value="isChecked(option)"
        @update:model-value="checked => toggleOption(option, checked)"
      />
      <span class="break-words">{{ option }}</span>
    </label>
  </div>
  <TextArea
    v-else-if="field.field_type === 'textarea'"
    :model-value="modelValue || ''"
    :max-length="TEXTAREA_MAX_LENGTH"
    auto-height
    @update:model-value="value => change(value, { commit: false })"
    @blur="emit('commit', modelValue)"
  />
  <Input
    v-else
    :model-value="modelValue || ''"
    :size="FIELD_SIZE"
    :custom-input-class="FIELD_INPUT_CLASS"
    :type="INPUT_TYPES[field.field_type]"
    @update:model-value="value => change(value, { commit: false })"
    @blur="emit('commit', modelValue)"
  />
</template>
