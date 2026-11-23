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
import TicketCustomFieldInput from 'dashboard/components-next/ticketFields/TicketCustomFieldInput.vue';
import { FIELD_LABEL_CLASS } from 'dashboard/constants/ticketFieldLayout';
import {
  FIELD_GROUPS,
  itemsInGroup,
  fieldDisplayName,
} from 'dashboard/helper/ticketFieldGroups';

const props = defineProps({
  group: {
    type: String,
    default: FIELD_GROUPS.OTHER,
    validator: value => Object.values(FIELD_GROUPS).includes(value),
  },
  // Dentro de "Ações da conversa" não tem aviso de vazio nem recuo próprio.
  inline: { type: Boolean, default: false },
});

const { t } = useI18n();
const currentChat = useMapGetter('getSelectedChat');
const { items, values, load, saveValue } =
  useConversationCustomFields(currentChat);

// Rascunho dos campos de texto/data até sair do campo.
// Troca de conversa recomeça dos valores salvos; atualização em tempo real da
// mesma conversa só troca o rascunho dos campos que mudaram de verdade (o que
// o agente ainda digita em outro campo não some).
const drafts = ref({});
watch(
  () => currentChat.value?.id,
  () => {
    drafts.value = { ...values.value };
  },
  { immediate: true }
);
watch(values, (next, previous) => {
  Object.keys({ ...next, ...previous }).forEach(key => {
    if (JSON.stringify(next[key]) !== JSON.stringify(previous?.[key])) {
      drafts.value[key] = next[key];
    }
  });
});

// Texto e data ficam num rascunho até sair do campo; o resto grava na hora.
const DRAFT_TYPES = ['text', 'textarea', 'date', 'datetime'];
const valueOf = field =>
  DRAFT_TYPES.includes(field.field_type)
    ? drafts.value[field.key]
    : values.value[field.key];

const groupItems = computed(() => itemsInGroup(items.value, props.group));
const editableItems = computed(() =>
  groupItems.value.filter(item => item.editable_by_agents)
);
const readOnlyItems = computed(() =>
  groupItems.value.filter(item => !item.editable_by_agents)
);

const save = async (key, value) => {
  if (JSON.stringify(values.value[key] ?? '') === JSON.stringify(value ?? ''))
    return;
  try {
    await saveValue(key, value);
  } catch (error) {
    useAlert(t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.SAVE_ERROR'));
  }
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
      class="flex flex-col gap-1.5"
    >
      <span class="break-words" :class="FIELD_LABEL_CLASS">
        {{ fieldDisplayName(field) }}
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
      <TicketCustomFieldInput
        :field="field"
        :model-value="valueOf(field)"
        @update:model-value="value => (drafts[field.key] = value)"
        @commit="value => save(field.key, value)"
      />
    </div>
    <div
      v-for="{ field } in readOnlyItems"
      :key="field.id"
      class="flex flex-col gap-0.5"
    >
      <span class="break-words" :class="FIELD_LABEL_CLASS">
        {{ fieldDisplayName(field) }}
      </span>
      <span class="text-xs break-words text-n-slate-12">
        {{ displayValue(values[field.key]) }}
      </span>
    </div>
  </div>
</template>
