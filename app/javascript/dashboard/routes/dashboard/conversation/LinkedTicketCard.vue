<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { getLastMessage } from 'dashboard/helper/conversationHelper';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  relationLabel: { type: String, required: true },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { getPlainText } = useMessageFormatter();

const conversationGetter = useMapGetter('getConversationById');
const contactGetter = useMapGetter('contacts/getContact');

const conversation = computed(() =>
  conversationGetter.value(props.conversationId)
);

onMounted(() => {
  if (!conversation.value) {
    store.dispatch('getConversation', props.conversationId);
  }
});

const contact = computed(
  () => contactGetter.value(conversation.value?.meta?.sender?.id) || {}
);

// Conversas do Chatwoot não têm um "assunto" formal como o ticket do Portal
// (só as sincronizadas do Portal têm custom_attributes.assunto) — pra
// identificar qualquer ticket vinculado, mesmo um ticket interno nativo,
// cai pra última mensagem e por último pro nome do contato.
const preview = computed(() => {
  if (!conversation.value) return '';
  const lastMessageContent = getLastMessage(conversation.value)?.content;
  return (
    conversation.value.custom_attributes?.assunto ||
    (lastMessageContent ? getPlainText(lastMessageContent) : '') ||
    contact.value.name ||
    ''
  );
});

const assigneeName = computed(
  () => conversation.value?.meta?.assignee?.name || null
);

const STATUS_BADGE_CLASS = {
  [wootConstants.STATUS_TYPE.OPEN]: 'bg-n-ruby-3 text-n-ruby-11',
  [wootConstants.STATUS_TYPE.PENDING]: 'bg-n-amber-3 text-n-amber-11',
  [wootConstants.STATUS_TYPE.SNOOZED]: 'bg-n-amber-3 text-n-amber-11',
  [wootConstants.STATUS_TYPE.RESOLVED]: 'bg-n-teal-3 text-n-teal-11',
};

const statusBadgeClass = computed(
  () =>
    STATUS_BADGE_CLASS[conversation.value?.status] ||
    'bg-n-slate-3 text-n-slate-11'
);

const goToConversation = () => {
  router.push({
    path: frontendURL(
      conversationUrl({
        accountId: route.params.accountId,
        id: props.conversationId,
      })
    ),
  });
};
</script>

<template>
  <button
    type="button"
    class="flex flex-col gap-1 p-2 w-full text-left rounded-lg outline outline-1 outline-n-weak hover:outline-n-slate-6 hover:bg-n-alpha-1 transition-colors"
    @click="goToConversation"
  >
    <span class="text-xs text-n-slate-11">{{ relationLabel }}</span>
    <span class="text-sm font-medium truncate text-n-slate-12">
      #{{ conversationId }}<template v-if="preview"> · {{ preview }}</template>
    </span>
    <div v-if="conversation" class="flex items-center justify-between gap-2">
      <span class="text-xs truncate text-n-slate-11">
        {{
          assigneeName || t('CONVERSATION_SIDEBAR.LINKED_TICKETS.UNASSIGNED')
        }}
      </span>
      <span
        class="shrink-0 px-1.5 py-0.5 rounded-full text-xxs font-medium"
        :class="statusBadgeClass"
      >
        {{
          t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${conversation.status}.TEXT`)
        }}
      </span>
    </div>
  </button>
</template>
