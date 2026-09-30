<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'next/icon/Icon.vue';
import FormattedContent from './bubbles/Text/FormattedContent.vue';
import AttachmentChips from './chips/AttachmentChips.vue';

import { messageTimestamp } from 'shared/helpers/timeHelper';
import { useMessageEditing } from 'dashboard/composables/useMessageEditing';
import { MESSAGE_TYPES, IMPORTED_TICKET_HISTORY_ROLES } from './constants';
import { useMessageContext } from './provider.js';

const { t } = useI18n();
const { editingMessage, startEditing } = useMessageEditing();

const {
  id,
  content,
  attachments,
  contentAttributes,
  sender,
  messageType,
  private: isPrivateMessage,
  createdAt,
  conversationId,
} = useMessageContext();

// `accent` fica na borda esquerda pro cliente e direita pra agente/nota
// interna - indica "o lado" (cliente vs. equipe) sem estreitar o card,
// que continua ocupando a largura toda da coluna (pedido explícito: "a
// largura tem que ser na pagina toda, so mudando o lado").
const ROLE_STYLES = {
  [IMPORTED_TICKET_HISTORY_ROLES.CUSTOMER]: {
    badge: 'bg-n-slate-4 text-n-slate-12',
    icon: 'i-lucide-user-round',
    accent: 'border-l-4 border-l-n-teal-9',
  },
  [IMPORTED_TICKET_HISTORY_ROLES.AGENT]: {
    badge: 'bg-n-solid-blue text-n-slate-12',
    icon: 'i-lucide-send',
    accent: 'border-r-4 border-r-n-blue-9',
  },
  [IMPORTED_TICKET_HISTORY_ROLES.INTERNAL]: {
    badge: 'bg-n-solid-amber text-n-amber-12',
    icon: 'i-lucide-lock-keyhole',
    accent: 'border-r-4 border-r-n-amber-9',
  },
};

// Mensagens antigas copiadas antes desse metadado existir não têm
// `importedRole` gravado - nesse caso deriva da mesma forma que o backend
// (`private` primeiro, depois `messageType`) em vez de quebrar o card.
const role = computed(() => {
  const attrRole = contentAttributes.value?.importedRole;
  if (attrRole && ROLE_STYLES[attrRole]) return attrRole;
  if (isPrivateMessage.value) return IMPORTED_TICKET_HISTORY_ROLES.INTERNAL;
  return messageType.value === MESSAGE_TYPES.OUTGOING
    ? IMPORTED_TICKET_HISTORY_ROLES.AGENT
    : IMPORTED_TICKET_HISTORY_ROLES.CUSTOMER;
});

const ROLE_LABEL_KEYS = {
  [IMPORTED_TICKET_HISTORY_ROLES.CUSTOMER]:
    'CONVERSATION.IMPORTED_TICKET_HISTORY.ROLE_CUSTOMER',
  [IMPORTED_TICKET_HISTORY_ROLES.AGENT]:
    'CONVERSATION.IMPORTED_TICKET_HISTORY.ROLE_AGENT',
  [IMPORTED_TICKET_HISTORY_ROLES.INTERNAL]:
    'CONVERSATION.IMPORTED_TICKET_HISTORY.ROLE_INTERNAL',
};

const roleStyle = computed(() => ROLE_STYLES[role.value]);
const roleLabel = computed(() => t(ROLE_LABEL_KEYS[role.value]));

const authorName = computed(
  () =>
    contentAttributes.value?.originalSenderName ||
    sender.value?.name ||
    t('CONVERSATION.BOT')
);

const avatarInfo = computed(() => ({
  name: authorName.value,
  src: sender.value?.thumbnail || '',
}));

const displayTimestamp = computed(() => {
  const original = contentAttributes.value?.originalCreatedAt;
  return messageTimestamp(original || createdAt.value, 'LLL d, y, h:mm a');
});

const originInboxName = computed(
  () => contentAttributes.value?.originalInboxName
);

const hasAttachments = computed(
  () => Array.isArray(attachments.value) && attachments.value.length > 0
);

const isEmpty = computed(() => !content.value && !hasAttachments.value);

// Igual ao resto do Chatwoot (ver TextBubble): só mensagem de saída
// (agente/nota interna) pode ser editada - reescrever o que o cliente
// escreveu não faz sentido e quebraria a fidelidade do histórico.
const isEditable = computed(
  () => role.value !== IMPORTED_TICKET_HISTORY_ROLES.CUSTOMER
);

// Editar não abre mais a barra de formatação inline no card - move o
// rascunho pra caixa principal (ReplyBox), igual o resto do Chatwoot
// (ver Message.vue/Text/Index.vue). `isEditing` aqui só marca visualmente
// qual card está sendo editado.
const isEditing = computed(() => editingMessage.value?.id === id.value);

const startEdit = () => {
  startEditing({
    id: id.value,
    conversationId: conversationId.value,
    content: content.value,
    attachments: attachments.value,
    senderName: authorName.value,
  });
};
</script>

<template>
  <div
    class="flex flex-col w-full gap-3 p-4 my-2 border rounded-lg shadow-sm border-n-weak bg-n-solid-1"
    :class="[roleStyle.accent, { 'ring-2 ring-n-brand ring-inset': isEditing }]"
  >
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div class="flex items-center min-w-0 gap-2">
        <Avatar :name="avatarInfo.name" :src="avatarInfo.src" :size="28" />
        <span class="text-sm font-medium truncate text-n-slate-12">
          {{ authorName }}
        </span>
        <span
          class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium shrink-0"
          :class="roleStyle.badge"
        >
          <Icon :icon="roleStyle.icon" class="size-3" />
          {{ roleLabel }}
        </span>
      </div>
      <div class="flex items-center gap-2 text-xs shrink-0 text-n-slate-11">
        <span v-if="originInboxName">
          {{
            t('CONVERSATION.IMPORTED_TICKET_HISTORY.ORIGIN', {
              inbox: originInboxName,
            })
          }}
        </span>
        <time>{{ displayTimestamp }}</time>
        <button
          v-if="isEditable && !isEditing"
          class="text-n-slate-10 hover:text-n-slate-12"
          :title="$t('CONVERSATION.CONTEXT_MENU.EDIT')"
          @click="startEdit"
        >
          <Icon icon="i-lucide-pencil" class="size-3.5" />
        </button>
      </div>
    </div>
    <div class="text-sm text-n-slate-12">
      <span v-if="isEmpty" class="text-n-slate-11">
        {{ t('CONVERSATION.IMPORTED_TICKET_HISTORY.NO_CONTENT') }}
      </span>
      <FormattedContent v-else-if="content" :content="content" />
      <span
        v-if="isEditing"
        class="block mt-1 text-xs font-medium text-n-brand"
      >
        {{ $t('CONVERSATION.EDITING_IN_PROGRESS') }}
      </span>
    </div>
    <AttachmentChips
      v-if="hasAttachments"
      :attachments="attachments"
      class="gap-2"
    />
  </div>
</template>
