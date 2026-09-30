<script setup>
// PATCH LOCAL (fork) - "Incluir em ticket existente": irmão do "Criar
// ticket interno" (NewInternalTicket.vue) na barra de mensagens
// selecionadas. Em vez de criar uma conversa nova, copia as mensagens pra
// um ticket que já existe, usando o mesmo copy_messages
// (Conversations::CopyMessagesService) - as mensagens entram como bloco de
// histórico, com autor/data/caixa originais.
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import ConversationApi from 'dashboard/api/inbox/conversation';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const { t } = useI18n();
const store = useStore();
const inboxGetter = useMapGetter('inboxes/getInbox');

const dialogRef = ref(null);
const sourceConversationId = ref(null);
const messageIds = ref([]);
const tickets = ref([]);
const selectedTicketId = ref(null);
const ticketNumber = ref('');
const isLoading = ref(false);
const isSubmitting = ref(false);

// Ticket = conversa em caixa Channel::Api (Portal do Cliente / Tickets
// Internos) - mesma regra do card de timeline em Message.vue.
const isTicketInbox = inboxId =>
  inboxGetter.value(inboxId)?.channel_type === INBOX_TYPES.API;

const typedTicketId = computed(() => {
  const value = Number(String(ticketNumber.value).replace('#', '').trim());
  return Number.isInteger(value) && value > 0 ? value : null;
});

const targetTicketId = computed(
  () => typedTicketId.value || selectedTicketId.value
);

const ticketSubject = ticket =>
  ticket.custom_attributes?.assunto || t('ADD_TO_TICKET_DIALOG.NO_SUBJECT');

const loadContactTickets = async contactId => {
  isLoading.value = true;
  try {
    await store.dispatch('contactConversations/get', contactId);
    tickets.value = store.getters[
      'contactConversations/getContactConversation'
    ](contactId).filter(
      ticket =>
        ticket.id !== sourceConversationId.value &&
        ticket.status !== 'resolved' &&
        isTicketInbox(ticket.inbox_id)
    );
  } finally {
    isLoading.value = false;
  }
};

const open = ({ sourceConversationId: sourceId, selectedIds, contactId }) => {
  sourceConversationId.value = sourceId;
  messageIds.value = selectedIds;
  tickets.value = [];
  selectedTicketId.value = null;
  ticketNumber.value = '';
  dialogRef.value?.open();
  if (contactId) loadContactTickets(contactId);
};

// Número digitado pode ser de qualquer conversa da conta - confirma que
// existe e que é um ticket antes de copiar (não inclui em WhatsApp etc.).
const ensureTypedTicketIsValid = async () => {
  if (!typedTicketId.value) return true;
  if (typedTicketId.value === sourceConversationId.value) return false;
  try {
    const { data } = await ConversationApi.show(typedTicketId.value);
    return isTicketInbox(data.inbox_id);
  } catch (error) {
    return false;
  }
};

const onConfirm = async () => {
  if (!targetTicketId.value) return;
  isSubmitting.value = true;
  try {
    if (!(await ensureTypedTicketIsValid())) {
      useAlert(t('ADD_TO_TICKET_DIALOG.INVALID_TICKET'));
      return;
    }
    await store.dispatch('copyMessages', {
      conversationId: targetTicketId.value,
      sourceConversationId: sourceConversationId.value,
      messageIds: messageIds.value,
    });
    useAlert(t('ADD_TO_TICKET_DIALOG.SUCCESS', { id: targetTicketId.value }), {
      type: 'link',
      to: `/app/accounts/${store.getters.getCurrentAccountId}/conversations/${targetTicketId.value}`,
      message: t('NEW_INTERNAL_TICKET_DIALOG.VIEW_TICKET'),
    });
    dialogRef.value?.close();
  } catch (error) {
    useAlert(t('ADD_TO_TICKET_DIALOG.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('ADD_TO_TICKET_DIALOG.TITLE')"
    :description="
      t('ADD_TO_TICKET_DIALOG.DESCRIPTION', { count: messageIds.length })
    "
    :confirm-button-label="t('ADD_TO_TICKET_DIALOG.CONFIRM')"
    :is-loading="isSubmitting"
    :disable-confirm-button="!targetTicketId"
    @confirm="onConfirm"
  >
    <div class="flex flex-col gap-4 w-full">
      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('ADD_TO_TICKET_DIALOG.CONTACT_TICKETS') }}
        </span>
        <p v-if="isLoading" class="text-sm text-n-slate-11">
          {{ t('ADD_TO_TICKET_DIALOG.LOADING') }}
        </p>
        <p v-else-if="!tickets.length" class="text-sm text-n-slate-11">
          {{ t('ADD_TO_TICKET_DIALOG.EMPTY') }}
        </p>
        <div
          v-else
          class="flex flex-col max-h-64 overflow-y-auto rounded-lg border border-n-weak divide-y divide-n-weak"
        >
          <label
            v-for="ticket in tickets"
            :key="ticket.id"
            class="flex items-center gap-3 px-3 py-2 cursor-pointer hover:bg-n-alpha-1"
            :class="{
              'bg-n-alpha-2': !typedTicketId && selectedTicketId === ticket.id,
            }"
          >
            <input
              v-model="selectedTicketId"
              type="radio"
              name="target-ticket"
              :value="ticket.id"
              :disabled="!!typedTicketId"
            />
            <span class="text-sm text-n-slate-11 shrink-0">
              {{ t('ADD_TO_TICKET_DIALOG.TICKET_NUMBER', { id: ticket.id }) }}
            </span>
            <span class="text-sm text-n-slate-12 truncate">
              {{ ticketSubject(ticket) }}
            </span>
            <span class="ml-auto text-xs text-n-slate-10 shrink-0">
              {{ inboxGetter(ticket.inbox_id)?.name }}
            </span>
          </label>
        </div>
      </div>
      <Input
        v-model="ticketNumber"
        :label="t('ADD_TO_TICKET_DIALOG.NUMBER_LABEL')"
        :placeholder="t('ADD_TO_TICKET_DIALOG.NUMBER_PLACEHOLDER')"
      />
    </div>
  </Dialog>
</template>
