<script setup>
import { ref, computed } from 'vue';
import { useRoute } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import TicketsAPI from 'dashboard/api/tickets';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import ContactDetailsItem from './ContactDetailsItem.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TicketVisibilityToggle from 'dashboard/components-next/NewConversation/TicketVisibilityToggle.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { INTERNAL_TICKETS_INBOX_NAME } from 'dashboard/composables/useTicketCatalog';
import {
  ASSUNTO_ATTRIBUTE_KEY,
  TICKET_ID_EXTERNO_ATTRIBUTE_KEY,
} from 'dashboard/constants/ticketDetailAttributes';

// Motivo do 422 do vínculo (Conversations::TicketLinkService::InvalidLink).
const LINK_ERRORS = {
  self: 'TICKET_LINK_DIALOG.LINK_ERRORS.SELF',
  cycle: 'TICKET_LINK_DIALOG.LINK_ERRORS.CYCLE',
};

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const { getPlainText } = useMessageFormatter();

const currentChat = useMapGetter('getSelectedChat');
const teams = useMapGetter('teams/getTeams');
const agentsList = useMapGetter('agents/getAgents');
const inboxes = useMapGetter('inboxes/getInboxes');

// Sem fallback pra outra caixa de propósito: um ticket pai/filho novo tem
// que ir sempre pra "Tickets Internos", nunca herdar a caixa da conversa
// original (que normalmente é Portal do Cliente) - senão dispara automação
// de cliente por engano, igual aconteceu antes dessa correção.
const targetInbox = computed(() =>
  inboxes.value.find(inbox => inbox.name === INTERNAL_TICKETS_INBOX_NAME)
);

const dialogRef = ref(null);
const linkMode = ref(null);
const internalTicketAgent = ref(null);
const internalTicketTeam = ref(null);
const internalTicketMessage = ref('');
const visibleToClient = ref(false);
const existingTicketQuery = ref('');
const existingTicketResults = ref([]);
const isSearchingExisting = ref(false);
const isLinkingExisting = ref(false);
const isCreatingInternalTicket = ref(false);

const canCreateInternalTicket = computed(
  () =>
    !!internalTicketTeam.value &&
    !!internalTicketMessage.value.trim() &&
    !!targetInbox.value &&
    !isCreatingInternalTicket.value
);
const showCreateForm = computed(
  () => linkMode.value === 'newChild' || linkMode.value === 'newParent'
);
const showExistingSearch = computed(
  () =>
    linkMode.value === 'existingChild' || linkMode.value === 'existingParent'
);
const linkFormTitle = computed(() => {
  const titleKeys = {
    newChild: 'TICKET_LINK_DIALOG.TITLES.NEW_CHILD',
    newParent: 'TICKET_LINK_DIALOG.TITLES.NEW_PARENT',
    existingChild: 'TICKET_LINK_DIALOG.TITLES.EXISTING_CHILD',
    existingParent: 'TICKET_LINK_DIALOG.TITLES.EXISTING_PARENT',
  };
  return t(titleKeys[linkMode.value] || 'TICKET_LINK_DIALOG.TITLES.DEFAULT');
});

const reset = () => {
  linkMode.value = null;
  internalTicketAgent.value = null;
  internalTicketTeam.value = null;
  internalTicketMessage.value = '';
  visibleToClient.value = false;
  existingTicketQuery.value = '';
  existingTicketResults.value = [];
};

const open = mode => {
  linkMode.value = mode;
  dialogRef.value?.open();
};

const close = () => {
  dialogRef.value?.close();
};

const onSelectInternalTicketAgent = selectedAgent => {
  internalTicketAgent.value = selectedAgent;

  const agentTeamIds = selectedAgent?.team_ids || [];
  const matchingTeam = teams.value.find(team => agentTeamIds.includes(team.id));
  if (matchingTeam) {
    internalTicketTeam.value = matchingTeam;
  }
};

const messagePreview = result => {
  const content = result.message && result.message.content;
  return content ? getPlainText(content) : '';
};

const searchExistingTicket = async () => {
  if (!existingTicketQuery.value.trim()) {
    existingTicketResults.value = [];
    return;
  }
  isSearchingExisting.value = true;
  try {
    await store.dispatch('conversationSearch/conversationSearch', {
      q: existingTicketQuery.value.trim(),
    });
    existingTicketResults.value = store.getters[
      'conversationSearch/getConversationRecords'
    ].filter(result => result.id !== currentChat.value.id);
  } finally {
    isSearchingExisting.value = false;
  }
};

// O servidor grava as duas pontas juntas e tira o ticket do pai antigo
// (Conversations::TicketLinkService); vínculo que faria ciclo volta com erro.
const linkExistingTicket = async picked => {
  isLinkingExisting.value = true;
  try {
    await store.dispatch('linkTicket', {
      conversationId: currentChat.value.id,
      relation: linkMode.value === 'existingParent' ? 'parent' : 'child',
      ticketId: picked.id,
    });
    useAlert(t('TICKET_LINK_DIALOG.LINK_SUCCESS'));
    close();
  } catch (error) {
    const reason = LINK_ERRORS[error.response?.data?.error];
    useAlert(t(reason || 'TICKET_LINK_DIALOG.LINK_ERROR'));
  } finally {
    isLinkingExisting.value = false;
  }
};

const SUBJECT_MAX_LENGTH = 150;

// Ticket, time, responsável, assunto, vínculo e o aviso na conversa original
// numa chamada só (Conversations::InternalTicketService): falhou, nada fica
// criado e dá pra tentar de novo sem duplicar.
const onCreateInternalTicket = async () => {
  const targetTeam = internalTicketTeam.value;
  if (!canCreateInternalTicket.value) return;

  const conv = currentChat.value;
  const accountId = route.params.accountId;
  const isParentMode = linkMode.value === 'newParent';
  const relationLabel = isParentMode ? 'pai' : 'filho';
  // PATCH LOCAL (fork) - assunto é o que o agente escreveu em "Descreva o
  // ticket" (1ª linha, cortada no limite), não mais "Ticket pai · Time".
  const firstLine = internalTicketMessage.value.trim().split('\n')[0].trim();
  const assunto =
    firstLine.length > SUBJECT_MAX_LENGTH
      ? `${firstLine.slice(0, SUBJECT_MAX_LENGTH - 1)}…`
      : firstLine;
  // Número do Portal quando a conversa já tem ticket lá - o id da conversa
  // não é o mesmo do ticket.
  const {
    [TICKET_ID_EXTERNO_ATTRIBUTE_KEY]: protocolo,
    ticket_id: portalTicketId,
  } = conv.custom_attributes || {};
  const originReference = portalTicketId
    ? `do ticket #${portalTicketId} do Portal (conversa #${conv.id})`
    : `da conversa #${conv.id}`;
  const originalUrl = `${window.location.origin}/app/accounts/${accountId}/conversations/${conv.id}`;
  // Visível ao cliente: só a descrição - o link e o roteamento por time são
  // da equipe. O vínculo pai/filho aparece no Portal de qualquer jeito.
  const content = visibleToClient.value
    ? internalTicketMessage.value.trim()
    : [
        `Ticket ${relationLabel} para o time ${targetTeam.name}, a partir ${originReference}${
          protocolo ? ` (Protocolo ${protocolo})` : ''
        }.`,
        `Conversa original: ${originalUrl}`,
        '',
        internalTicketMessage.value.trim(),
      ].join('\n');

  isCreatingInternalTicket.value = true;
  try {
    const { data } = await TicketsAPI.createInternalTicket({
      inbox_id: targetInbox.value.id,
      contact_id: conv.meta.sender.id,
      team_id: targetTeam.id,
      assignee_id: internalTicketAgent.value?.id,
      custom_attributes: { [ASSUNTO_ATTRIBUTE_KEY]: assunto },
      message: { content, private: !visibleToClient.value },
      link: {
        conversation_id: conv.id,
        relation: isParentMode ? 'parent' : 'child',
        announce: true,
      },
    });

    useAlert(
      t(
        isParentMode
          ? 'TICKET_LINK_DIALOG.CREATE_SUCCESS.PARENT'
          : 'TICKET_LINK_DIALOG.CREATE_SUCCESS.CHILD'
      ),
      {
        type: 'link',
        to: `/app/accounts/${accountId}/conversations/${data.id}`,
        message: t('TICKET_LINK_DIALOG.VIEW_TICKET'),
      }
    );

    close();
  } catch (error) {
    useAlert(t('TICKET_LINK_DIALOG.CREATE_ERROR'));
  } finally {
    isCreatingInternalTicket.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    show-close-button
    :title="linkFormTitle"
    width="sm"
    :show-confirm-button="false"
    :cancel-button-label="$t('TICKET_LINK_DIALOG.CLOSE_BUTTON')"
    @close="reset"
  >
    <div v-if="showCreateForm" class="flex flex-col gap-2 w-full">
      <TicketVisibilityToggle v-model="visibleToClient" />
      <div>
        <ContactDetailsItem
          compact
          :title="$t('CONVERSATION_SIDEBAR.ASSIGNEE_LABEL')"
        />
        <MultiselectDropdown
          :options="agentsList"
          :selected-item="internalTicketAgent"
          :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.AGENT')"
          :multiselector-placeholder="
            $t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')
          "
          :no-search-result="
            $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')
          "
          :input-placeholder="
            $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')
          "
          @select="onSelectInternalTicketAgent"
        />
      </div>
      <div>
        <ContactDetailsItem
          compact
          :title="$t('CONVERSATION_SIDEBAR.TEAM_LABEL')"
        />
        <MultiselectDropdown
          :options="teams"
          :selected-item="internalTicketTeam"
          show-emoji-icon
          :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.TEAM')"
          :multiselector-placeholder="
            $t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')
          "
          :no-search-result="
            $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.TEAM')
          "
          :input-placeholder="
            $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.TEAM')
          "
          @select="internalTicketTeam = $event"
        />
      </div>
      <textarea
        v-model="internalTicketMessage"
        rows="3"
        :placeholder="$t('TICKET_LINK_DIALOG.MESSAGE_PLACEHOLDER')"
        class="w-full p-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
      />
      <NextButton
        size="sm"
        justify="center"
        class="w-full"
        icon="i-lucide-git-branch-plus"
        :is-loading="isCreatingInternalTicket"
        :disabled="!canCreateInternalTicket"
        :label="$t('TICKET_LINK_DIALOG.CREATE_BUTTON')"
        @click="onCreateInternalTicket"
      />
      <p v-if="!targetInbox" class="text-xs text-n-ruby-11">
        {{ $t('TICKET_LINK_DIALOG.NO_INTERNAL_INBOX') }}
      </p>
    </div>

    <div v-else-if="showExistingSearch" class="flex flex-col gap-2 w-full">
      <div class="flex gap-2">
        <input
          v-model="existingTicketQuery"
          type="text"
          :placeholder="$t('TICKET_LINK_DIALOG.SEARCH_PLACEHOLDER')"
          class="flex-1 h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
          @keyup.enter="searchExistingTicket"
        />
        <NextButton
          size="sm"
          :label="$t('TICKET_LINK_DIALOG.SEARCH_BUTTON')"
          :is-loading="isSearchingExisting"
          @click="searchExistingTicket"
        />
      </div>
      <ul
        v-if="existingTicketResults.length"
        class="max-h-52 overflow-y-auto border border-n-weak rounded-md"
      >
        <li
          v-for="result in existingTicketResults"
          :key="result.id"
          class="px-2 py-1 text-sm cursor-pointer hover:bg-n-alpha-2 border-b border-n-weak last:border-0"
          @click="linkExistingTicket(result)"
        >
          <span class="text-n-brand">#{{ result.id }}</span>
          {{ result.contact ? result.contact.name : '' }} ·
          {{ messagePreview(result) }}
        </li>
      </ul>
      <p
        v-else-if="!isSearchingExisting && existingTicketQuery"
        class="text-xs text-n-slate-11"
      >
        {{ $t('TICKET_LINK_DIALOG.NO_RESULTS') }}
      </p>
    </div>
  </Dialog>
</template>
