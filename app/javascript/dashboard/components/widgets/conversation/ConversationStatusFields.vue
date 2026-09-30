<script setup>
// PATCH LOCAL (fork) - Status do atendimento e Justificativa (cadastros) no
// cabeçalho da conversa, ao lado do Resolver.
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import {
  STATUS_ATENDIMENTO_ATTRIBUTE_KEY,
  JUSTIFICATIVA_ATTRIBUTE_KEY,
} from 'dashboard/constants/ticketDetailAttributes';
import {
  useTicketCatalog,
  conversationTicketScope,
} from 'dashboard/composables/useTicketCatalog';
import {
  activeInScope,
  justificationsForStatus,
} from 'dashboard/helper/ticketCatalogRules';
import { useConversationCustomFields } from 'dashboard/composables/useConversationCustomFields';
import { useSaveConversationAttributes } from 'dashboard/composables/useSaveConversationAttributes';

// Status do cadastro que resolvem a conversa (TicketStatusSync no backend).
const CONCLUDING_STATUS_BASES = ['resolvido', 'fechado'];

const { t } = useI18n();
const currentChat = useMapGetter('getSelectedChat');
const getInbox = useMapGetter('inboxes/getInbox');
const { state: catalog, fetchList } = useTicketCatalog();
const { missingOnResolve, load: loadCustomFields } =
  useConversationCustomFields(currentChat);
const saveConversationAttributes = useSaveConversationAttributes();

const customAttributes = computed(
  () => currentChat.value.custom_attributes || {}
);
const ticketScope = computed(() =>
  conversationTicketScope(getInbox.value(currentChat.value.inbox_id))
);
const noneOption = computed(() => ({
  id: '',
  name: t('CONVERSATION.PRIORITY.OPTIONS.NONE'),
}));
// Valor gravado que saiu da lista (inativado, ou veio do Portal) continua
// aparecendo como selecionado em vez de sumir.
const catalogOptions = names => [
  noneOption.value,
  ...names.map(name => ({ id: name, name })),
];
const selectedOption = (options, key) => {
  const current = customAttributes.value[key];
  if (!current) return null;
  return (
    options.find(opt => opt.id === current) || { id: current, name: current }
  );
};

const selectedStatus = computed(() =>
  catalog.statuses.find(
    item =>
      item.name === customAttributes.value[STATUS_ATENDIMENTO_ATTRIBUTE_KEY]
  )
);
const statusOptions = computed(() =>
  catalogOptions(
    activeInScope(catalog.statuses, ticketScope.value).map(item => item.name)
  )
);
const statusJustifications = computed(() =>
  justificationsForStatus(
    catalog.justifications,
    selectedStatus.value,
    ticketScope.value
  )
);
const justificativaOptions = computed(() =>
  catalogOptions(statusJustifications.value.map(item => item.name))
);
const assignedStatus = computed(() =>
  selectedOption(statusOptions.value, STATUS_ATENDIMENTO_ATTRIBUTE_KEY)
);
const assignedJustificativa = computed(() =>
  selectedOption(justificativaOptions.value, JUSTIFICATIVA_ATTRIBUTE_KEY)
);
const isJustificationMissing = computed(
  () =>
    !!selectedStatus.value?.requires_justification &&
    !customAttributes.value[JUSTIFICATIVA_ATTRIBUTE_KEY]
);

onMounted(() => {
  fetchList('statuses');
  fetchList('justifications');
});

// Trocar o status limpa a justificativa que não vale pro status novo, no
// mesmo update. O backend acompanha o status nativo da conversa.
const onSelectStatus = async selectedItem => {
  const statusName =
    assignedStatus.value?.id === selectedItem.id ? '' : selectedItem.id;
  const status = catalog.statuses.find(item => item.name === statusName);
  // Status que resolve a conversa passa pela mesma trava do Resolver:
  // campo adicional obrigatório na conclusão precisa estar preenchido.
  if (CONCLUDING_STATUS_BASES.includes(status?.base)) {
    await loadCustomFields();
    if (missingOnResolve.value.length) {
      useAlert(
        t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.MISSING_ON_RESOLVE', {
          fields: missingOnResolve.value
            .map(item => item.field.name)
            .join(', '),
        })
      );
      return;
    }
  }
  const currentJustificativa =
    customAttributes.value[JUSTIFICATIVA_ATTRIBUTE_KEY];
  const stillValid = justificationsForStatus(
    catalog.justifications,
    status,
    ticketScope.value
  ).some(item => item.name === currentJustificativa);
  saveConversationAttributes(currentChat.value, {
    [STATUS_ATENDIMENTO_ATTRIBUTE_KEY]: statusName,
    [JUSTIFICATIVA_ATTRIBUTE_KEY]: stillValid ? currentJustificativa : '',
  });
};

const onSelectJustificativa = selectedItem => {
  const isSame = assignedJustificativa.value?.id === selectedItem.id;
  saveConversationAttributes(currentChat.value, {
    [JUSTIFICATIVA_ATTRIBUTE_KEY]: isSame ? '' : selectedItem.id,
  });
};
</script>

<template>
  <div class="flex items-center gap-2">
    <div
      class="w-44 [&_.mb-2]:!mb-0"
      :title="t('CONVERSATION_SIDEBAR.STATUS_ATENDIMENTO_LABEL')"
    >
      <MultiselectDropdown
        :options="statusOptions"
        :selected-item="assignedStatus"
        :multiselector-title="
          t('CONVERSATION_SIDEBAR.STATUS_ATENDIMENTO_LABEL')
        "
        :multiselector-placeholder="
          t('CONVERSATION_SIDEBAR.STATUS_ATENDIMENTO_LABEL')
        "
        :no-search-result="
          t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')
        "
        :input-placeholder="
          t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')
        "
        @select="onSelectStatus"
      />
    </div>
    <div
      v-if="statusJustifications.length"
      class="w-44 rounded-lg [&_.mb-2]:!mb-0"
      :class="{ 'ring-1 ring-n-amber-9': isJustificationMissing }"
      :title="
        isJustificationMissing
          ? t('CONVERSATION_SIDEBAR.JUSTIFICATION_REQUIRED')
          : t('CONVERSATION_SIDEBAR.JUSTIFICATIVA_LABEL')
      "
    >
      <MultiselectDropdown
        :options="justificativaOptions"
        :selected-item="assignedJustificativa"
        :multiselector-title="t('CONVERSATION_SIDEBAR.JUSTIFICATIVA_LABEL')"
        :multiselector-placeholder="
          t('CONVERSATION_SIDEBAR.JUSTIFICATIVA_LABEL')
        "
        :no-search-result="
          t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')
        "
        :input-placeholder="
          t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')
        "
        @select="onSelectJustificativa"
      />
    </div>
  </div>
</template>
