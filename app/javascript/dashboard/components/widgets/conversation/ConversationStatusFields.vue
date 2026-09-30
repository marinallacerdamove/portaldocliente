<script setup>
// PATCH LOCAL (fork) - Status do atendimento e Justificativa (cadastros) no
// cabeçalho da conversa, ao lado do Resolver.
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';
import { CMD_RESOLVE_CONVERSATION } from 'dashboard/helper/commandbar/events';
import { useMapGetter } from 'dashboard/composables/store';
import HeaderSelectDropdown from './HeaderSelectDropdown.vue';
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
import { useSaveConversationAttributes } from 'dashboard/composables/useSaveConversationAttributes';

// Status do cadastro que resolvem a conversa (TicketStatus::CONVERSATION_STATUS).
const CONCLUDING_STATUS_BASES = ['resolvido', 'fechado', 'cancelado'];

const { t } = useI18n();
const currentChat = useMapGetter('getSelectedChat');
const getInbox = useMapGetter('inboxes/getInbox');
const { state: catalog, fetchList } = useTicketCatalog();
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
const catalogOptions = names => [
  noneOption.value,
  ...names.map(name => ({ id: name, name })),
];
// Valor gravado que saiu da lista (inativado, ou veio do Portal) continua
// aparecendo pelo nome em vez de sumir (HeaderSelectDropdown).
const currentStatus = computed(
  () => customAttributes.value[STATUS_ATENDIMENTO_ATTRIBUTE_KEY] || ''
);
const currentJustificativa = computed(
  () => customAttributes.value[JUSTIFICATIVA_ATTRIBUTE_KEY] || ''
);

const selectedStatus = computed(() =>
  catalog.statuses.find(item => item.name === currentStatus.value)
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
const isJustificationMissing = computed(
  () =>
    !!selectedStatus.value?.requires_justification &&
    !currentJustificativa.value
);

onMounted(() => {
  fetchList('statuses');
  fetchList('justifications');
});

// Trocar o status limpa a justificativa que não vale pro status novo, no
// mesmo update. O backend acompanha o status nativo da conversa.
const onSelectStatus = selectedItem => {
  const statusName =
    currentStatus.value === selectedItem.id ? '' : selectedItem.id;
  const status = catalog.statuses.find(item => item.name === statusName);
  const stillValid = justificationsForStatus(
    catalog.justifications,
    status,
    ticketScope.value
  ).some(item => item.name === currentJustificativa.value);
  const changes = {
    [STATUS_ATENDIMENTO_ATTRIBUTE_KEY]: statusName,
    [JUSTIFICATIVA_ATTRIBUTE_KEY]: stillValid ? currentJustificativa.value : '',
  };
  // Status que resolve uma conversa ainda aberta vai pelo próprio Resolver:
  // mesma trava de campos obrigatórios e mesma pergunta do motivo.
  if (
    CONCLUDING_STATUS_BASES.includes(status?.base) &&
    currentChat.value.status !== 'resolved'
  ) {
    emitter.emit(CMD_RESOLVE_CONVERSATION, { attributes: changes });
    return;
  }
  saveConversationAttributes(currentChat.value, changes);
};

const onSelectJustificativa = selectedItem => {
  const isSame = currentJustificativa.value === selectedItem.id;
  saveConversationAttributes(currentChat.value, {
    [JUSTIFICATIVA_ATTRIBUTE_KEY]: isSame ? '' : selectedItem.id,
  });
};
</script>

<template>
  <div class="flex items-center gap-2">
    <HeaderSelectDropdown
      :options="statusOptions"
      :selected-id="currentStatus"
      :placeholder="t('CONVERSATION_SIDEBAR.STATUS_ATENDIMENTO_LABEL')"
      :title="t('CONVERSATION_SIDEBAR.STATUS_ATENDIMENTO_LABEL')"
      @select="onSelectStatus"
    />
    <HeaderSelectDropdown
      v-if="statusJustifications.length"
      :options="justificativaOptions"
      :selected-id="currentJustificativa"
      :placeholder="t('CONVERSATION_SIDEBAR.JUSTIFICATIVA_LABEL')"
      :title="
        isJustificationMissing
          ? t('CONVERSATION_SIDEBAR.JUSTIFICATION_REQUIRED')
          : t('CONVERSATION_SIDEBAR.JUSTIFICATIVA_LABEL')
      "
      :highlight="isJustificationMissing"
      @select="onSelectJustificativa"
    />
  </div>
</template>
