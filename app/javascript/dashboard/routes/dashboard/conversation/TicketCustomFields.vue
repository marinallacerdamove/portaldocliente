<script setup>
// PATCH LOCAL (fork) - campos adicionais da conversa (Movidesk: Campos
// adicionais), no acordeão da lateral. Só aparecem os que alguma regra de
// exibição inclui pro serviço, tipo de solicitação e valores atuais; mudar um
// valor pode abrir ou fechar outros campos (cascata). Lista e seleção única
// gravam na hora, texto e data ao sair do campo. `group` escolhe quais campos
// esta instância mostra (ver helper/ticketFieldGroups.js).
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useConversationCustomFields } from 'dashboard/composables/useConversationCustomFields';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { FIELD_GROUPS, itemsInGroup } from 'dashboard/helper/ticketFieldGroups';

const props = defineProps({
  group: {
    type: String,
    default: FIELD_GROUPS.OTHER,
    validator: value => Object.values(FIELD_GROUPS).includes(value),
  },
  // Dentro de "Ações da conversa" não tem aviso de vazio nem recuo próprio.
  inline: { type: Boolean, default: false },
});

const TEXTAREA_MAX_LENGTH = 5000;
const INPUT_TYPES = { text: 'text', date: 'date', datetime: 'datetime-local' };

const { t } = useI18n();
const currentChat = useMapGetter('getSelectedChat');
const { items, values, load, saveValue } =
  useConversationCustomFields(currentChat);

// Rascunho dos campos de texto/data até sair do campo.
const drafts = ref({});
watch(
  () => [currentChat.value?.id, values.value],
  () => {
    drafts.value = { ...values.value };
  },
  { immediate: true }
);

const groupItems = computed(() => itemsInGroup(items.value, props.group));
const editableItems = computed(() =>
  groupItems.value.filter(item => item.editable_by_agents)
);
const readOnlyItems = computed(() =>
  groupItems.value.filter(item => !item.editable_by_agents)
);

const optionsOf = field =>
  field.options.map(option => ({ value: option, label: option }));

const save = async (key, value) => {
  if (JSON.stringify(values.value[key] ?? '') === JSON.stringify(value ?? ''))
    return;
  try {
    await saveValue(key, value);
  } catch (error) {
    useAlert(t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.SAVE_ERROR'));
  }
};

const toggleOption = (field, option, checked) => {
  const selected = new Set(values.value[field.key] || []);
  if (checked) selected.add(option);
  else selected.delete(option);
  save(
    field.key,
    field.options.filter(item => selected.has(item))
  );
};

const displayValue = value =>
  Array.isArray(value) ? value.join(', ') : value || '--';

onMounted(load);
</script>

<template>
  <div
    v-if="!inline || groupItems.length"
    class="flex flex-col gap-4"
    :class="inline ? '' : 'px-2 py-4'"
  >
    <p v-if="!groupItems.length" class="mb-0 text-xs text-n-slate-10">
      {{ t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.EMPTY') }}
    </p>
    <div
      v-for="{ field, required_on: requiredOn } in editableItems"
      :key="field.id"
      class="flex flex-col gap-1"
    >
      <span class="text-xs font-medium break-words text-n-slate-12">
        {{ field.name }}
        <span
          v-if="requiredOn === 'conclusao'"
          v-tooltip.top="
            t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.REQUIRED')
          "
          class="inline-block align-middle i-lucide-asterisk size-3 text-n-ruby-11"
        />
      </span>
      <span v-if="field.hint" class="text-xs text-n-slate-10">
        {{ field.hint }}
      </span>
      <ComboBox
        v-if="
          field.field_type === 'list' || field.field_type === 'single_select'
        "
        :model-value="values[field.key] || ''"
        :options="optionsOf(field)"
        :display-label="values[field.key] || ''"
        :placeholder="
          t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.SELECT_PLACEHOLDER')
        "
        @update:model-value="value => save(field.key, value)"
      />
      <div
        v-else-if="field.field_type === 'multi_select'"
        class="flex flex-col gap-1.5"
      >
        <label
          v-for="option in field.options"
          :key="option"
          class="flex items-start gap-2 mb-0 text-xs cursor-pointer text-n-slate-12"
        >
          <Checkbox
            class="mt-0.5 shrink-0"
            :model-value="(values[field.key] || []).includes(option)"
            @update:model-value="
              checked => toggleOption(field, option, checked)
            "
          />
          <span class="break-words">{{ option }}</span>
        </label>
      </div>
      <TextArea
        v-else-if="field.field_type === 'textarea'"
        v-model="drafts[field.key]"
        :max-length="TEXTAREA_MAX_LENGTH"
        auto-height
        @blur="save(field.key, drafts[field.key])"
      />
      <Input
        v-else
        v-model="drafts[field.key]"
        :type="INPUT_TYPES[field.field_type]"
        @blur="save(field.key, drafts[field.key])"
      />
    </div>
    <div
      v-for="{ field } in readOnlyItems"
      :key="field.id"
      class="flex flex-col gap-0.5"
    >
      <span class="text-xs font-medium break-words text-n-slate-11">
        {{ field.name }}
      </span>
      <span class="text-xs break-words text-n-slate-12">
        {{ displayValue(values[field.key]) }}
      </span>
    </div>
  </div>
</template>
