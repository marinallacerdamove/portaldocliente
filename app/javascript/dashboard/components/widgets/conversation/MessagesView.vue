<script>
import { ref, computed, provide, useTemplateRef, watch } from 'vue';
import { useElementSize } from '@vueuse/core';
// composable
import { useLabelSuggestions } from 'dashboard/composables/useLabelSuggestions';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { useMapGetter } from 'dashboard/composables/store';
import { useMessageSelection } from 'dashboard/composables/useMessageSelection';
import { useMessageEditing } from 'dashboard/composables/useMessageEditing';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { MESSAGE_TYPE } from 'shared/constants/messages';

// components
import ReplyBox from './ReplyBox.vue';
import MessageEditBar from './MessageEditBar.vue';
import MessageList from 'next/message/MessageList.vue';
import ConversationLabelSuggestion from './conversation/LabelSuggestion.vue';
import Banner from 'dashboard/components/ui/Banner.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ResizableEditorWrapper from './ResizableEditorWrapper.vue';
import ReferralBubble from 'dashboard/components-next/Conversation/ReferralBubble.vue';
import NewInternalTicket from 'dashboard/components-next/NewConversation/NewInternalTicket.vue';
import AddToExistingTicket from 'dashboard/components-next/NewConversation/AddToExistingTicket.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
// PATCH LOCAL (fork) - checklists do ticket no topo da conversa.
import ConversationChecklists from 'dashboard/routes/dashboard/conversation/ConversationChecklists.vue';

// stores and apis
import { mapGetters } from 'vuex';

// mixins
import inboxMixin, { INBOX_FEATURES } from 'shared/mixins/inboxMixin';

// utils
import { emitter } from 'shared/helpers/mitt';
import { getTypingUsersText } from '../../../helper/commons';
import { calculateScrollTop } from './helpers/scrollTopCalculationHelper';
import { LocalStorage } from 'shared/helpers/localStorage';
import {
  filterDuplicateSourceMessages,
  getReadMessages,
  getUnreadMessages,
} from 'dashboard/helper/conversationHelper';

// constants
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { REPLY_POLICY } from 'shared/constants/links';
import wootConstants, {
  META_RESTRICTION_STATUS_URL,
} from 'dashboard/constants/globals';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

export default {
  components: {
    ConversationChecklists,
    MessageList,
    ReplyBox,
    MessageEditBar,
    Banner,
    ConversationLabelSuggestion,
    Spinner,
    ResizableEditorWrapper,
    ReferralBubble,
    NewInternalTicket,
    AddToExistingTicket,
    NextButton,
  },
  mixins: [inboxMixin],
  setup() {
    const conversationPanelRef = ref(null);
    const resizableEditorWrapperRef = ref(null);
    const messagesViewRef = useTemplateRef('messagesViewRef');
    const topBannerRef = useTemplateRef('topBannerRef');
    const { height: containerHeight } = useElementSize(messagesViewRef);
    const { height: topBannerHeight } = useElementSize(topBannerRef);

    // PATCH LOCAL (fork) - mensagens de atividade (etiqueta, atribuição,
    // status...) ficam ocultas por padrão pra não poluir o histórico; o
    // agente mostra/oculta pelo botão no topo da conversa (salvo por usuário).
    const { uiSettings, updateUISettings } = useUISettings();
    const showActivities = computed(
      () => !!uiSettings.value?.show_conversation_activities
    );
    const toggleActivities = () =>
      updateUISettings({
        show_conversation_activities: !showActivities.value,
      });

    const {
      captainTasksEnabled,
      isLabelSuggestionFeatureEnabled,
      getLabelSuggestions,
    } = useLabelSuggestions();

    const currentChatGetter = useMapGetter('getSelectedChat');
    const conversationId = computed(() => currentChatGetter.value.id);
    const {
      isSelectionModeActive,
      selectedMessageIds,
      selectedCount,
      toggleSelectionMode,
      toggleMessageSelection,
      clearSelection,
    } = useMessageSelection(conversationId);

    const newInternalTicketRef = useTemplateRef('newInternalTicketRef');
    const { editingMessage, stopEditing } = useMessageEditing();

    // Troca de conversa cancela edição pendente - editingMessage é um
    // singleton compartilhado (ver useMessageEditing.js), não escopado por
    // conversa, então sem isso a caixa de edição sobreviveria apontando pra
    // uma mensagem de outra conversa.
    watch(conversationId, (newId, oldId) => {
      if (newId !== oldId) stopEditing();
    });

    provide('contextMenuElementTarget', conversationPanelRef);

    return {
      showActivities,
      toggleActivities,
      captainTasksEnabled,
      getLabelSuggestions,
      isLabelSuggestionFeatureEnabled,
      conversationPanelRef,
      resizableEditorWrapperRef,
      messagesViewRef,
      topBannerRef,
      containerHeight,
      topBannerHeight,
      isSelectionModeActive,
      selectedMessageIds,
      selectedCount,
      toggleSelectionMode,
      toggleMessageSelection,
      clearSelection,
      newInternalTicketRef,
      editingMessage,
    };
  },
  data() {
    return {
      isLoadingPrevious: true,
      heightBeforeLoad: null,
      conversationPanel: null,
      hasUserScrolled: false,
      isProgrammaticScroll: false,
      messageSentSinceOpened: false,
      labelSuggestions: [],
    };
  },

  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      currentUserId: 'getCurrentUserID',
      listLoadingStatus: 'getAllMessagesLoaded',
      currentAccountId: 'getCurrentAccountId',
      isMetaMessageSendingDisabled: 'globalConfig/isMetaMessageSendingDisabled',
    }),
    isOpen() {
      return this.currentChat?.status === wootConstants.STATUS_TYPE.OPEN;
    },
    shouldShowLabelSuggestions() {
      return (
        this.isOpen &&
        this.captainTasksEnabled &&
        this.isLabelSuggestionFeatureEnabled &&
        !this.messageSentSinceOpened
      );
    },
    inboxId() {
      return this.currentChat.inbox_id;
    },
    inbox() {
      return this.$store.getters['inboxes/getInbox'](this.inboxId);
    },
    typingUsersList() {
      const userList = this.$store.getters[
        'conversationTypingStatus/getUserList'
      ](this.currentChat.id);
      return userList;
    },
    isAnyoneTyping() {
      const userList = this.typingUsersList;
      return userList.length !== 0;
    },
    typingUserNames() {
      const userList = this.typingUsersList;
      if (this.isAnyoneTyping) {
        const [i18nKey, params] = getTypingUsersText(userList);
        return this.$t(i18nKey, params);
      }

      return '';
    },
    allMessages() {
      const messages = this.currentChat.messages || [];
      if (this.isAWhatsAppChannel) {
        return filterDuplicateSourceMessages(messages);
      }
      return messages;
    },
    activityMessageCount() {
      return this.allMessages.filter(
        message => message.message_type === MESSAGE_TYPE.ACTIVITY
      ).length;
    },
    getMessages() {
      if (this.showActivities) return this.allMessages;
      return this.allMessages.filter(
        message => message.message_type !== MESSAGE_TYPE.ACTIVITY
      );
    },
    referralData() {
      return this.currentChat?.additional_attributes?.referral || null;
    },
    selectedMessagesSorted() {
      return this.getMessages
        .filter(message => this.selectedMessageIds.includes(message.id))
        .sort((a, b) => a.created_at - b.created_at);
    },
    readMessages() {
      return getReadMessages(
        this.getMessages,
        this.currentChat.agent_last_seen_at
      );
    },
    unReadMessages() {
      return getUnreadMessages(
        this.getMessages,
        this.currentChat.agent_last_seen_at
      );
    },
    shouldShowSpinner() {
      return (
        (this.currentChat && this.currentChat.dataFetched === undefined) ||
        (!this.listLoadingStatus && this.isLoadingPrevious)
      );
    },
    // Check there is a instagram inbox exists with the same instagram_id
    hasDuplicateInstagramInbox() {
      const instagramId = this.inbox.instagram_id;
      const { additional_attributes: additionalAttributes = {} } = this.inbox;
      const instagramInbox =
        this.$store.getters['inboxes/getInstagramInboxByInstagramId'](
          instagramId
        );

      return (
        this.inbox.channel_type === INBOX_TYPES.FB &&
        additionalAttributes.type === 'instagram_direct_message' &&
        instagramInbox
      );
    },
    isInstagramRestrictionBannerVisible() {
      return this.isMetaMessageSendingDisabled && this.isAnInstagramChannel;
    },
    instagramRestrictionStatusUrl() {
      return META_RESTRICTION_STATUS_URL;
    },
    replyWindowBannerMessage() {
      if (this.isAWhatsAppChannel) {
        return this.$t('CONVERSATION.TWILIO_WHATSAPP_CAN_REPLY');
      }
      if (this.isAPIInbox) {
        const { additional_attributes: additionalAttributes = {} } = this.inbox;
        if (additionalAttributes) {
          const {
            agent_reply_time_window_message: agentReplyTimeWindowMessage,
            agent_reply_time_window: agentReplyTimeWindow,
          } = additionalAttributes;
          return (
            agentReplyTimeWindowMessage ||
            this.$t('CONVERSATION.API_HOURS_WINDOW', {
              hours: agentReplyTimeWindow,
            })
          );
        }
        return '';
      }
      return this.$t('CONVERSATION.CANNOT_REPLY');
    },
    replyWindowLink() {
      if (this.isAFacebookInbox || this.isAnInstagramChannel) {
        return REPLY_POLICY.FACEBOOK;
      }
      if (this.isAWhatsAppCloudChannel) {
        return REPLY_POLICY.WHATSAPP_CLOUD;
      }
      if (this.isATiktokChannel) {
        return REPLY_POLICY.TIKTOK;
      }
      if (!this.isAPIInbox) {
        return REPLY_POLICY.TWILIO_WHATSAPP;
      }
      return '';
    },
    replyWindowLinkText() {
      if (
        this.isAWhatsAppChannel ||
        this.isAFacebookInbox ||
        this.isAnInstagramChannel
      ) {
        return this.$t('CONVERSATION.24_HOURS_WINDOW');
      }
      if (this.isATiktokChannel) {
        return this.$t('CONVERSATION.48_HOURS_WINDOW');
      }
      if (!this.isAPIInbox) {
        return this.$t('CONVERSATION.TWILIO_WHATSAPP_24_HOURS_WINDOW');
      }
      return '';
    },
    unreadMessageCount() {
      return this.currentChat.unread_count || 0;
    },
    unreadMessageLabel() {
      const count =
        this.unreadMessageCount > 9 ? '9+' : this.unreadMessageCount;
      const label =
        this.unreadMessageCount > 1
          ? 'CONVERSATION.UNREAD_MESSAGES'
          : 'CONVERSATION.UNREAD_MESSAGE';
      return `${count} ${this.$t(label)}`;
    },
    inboxSupportsReplyTo() {
      const incoming = this.inboxHasFeature(INBOX_FEATURES.REPLY_TO);
      const outgoing =
        this.inboxHasFeature(INBOX_FEATURES.REPLY_TO_OUTGOING) &&
        !this.is360DialogWhatsAppChannel;

      return { incoming, outgoing };
    },
  },

  watch: {
    currentChat(newChat, oldChat) {
      if (newChat.id === oldChat.id) {
        return;
      }
      this.fetchAllAttachmentsFromCurrentChat();
      this.fetchSuggestions();
      this.messageSentSinceOpened = false;
      this.resetReplyEditorHeight();
    },
  },

  created() {
    emitter.on(BUS_EVENTS.SCROLL_TO_MESSAGE, this.onScrollToMessage);
    // when a message is sent we set the flag to true this hides the label suggestions,
    // until the chat is changed and the flag is reset in the watch for currentChat
    emitter.on(BUS_EVENTS.MESSAGE_SENT, () => {
      this.messageSentSinceOpened = true;
    });
    emitter.on(
      BUS_EVENTS.TOGGLE_MESSAGE_SELECTION_MODE,
      this.toggleSelectionMode
    );
  },

  mounted() {
    this.addScrollListener();
    this.fetchAllAttachmentsFromCurrentChat();
    this.fetchSuggestions();
  },

  unmounted() {
    this.removeBusListeners();
    this.removeScrollListener();
  },

  methods: {
    async fetchSuggestions() {
      // start empty, this ensures that the label suggestions are not shown
      this.labelSuggestions = [];

      if (this.isLabelSuggestionDismissed()) {
        return;
      }

      // Early exit if conversation already has labels - no need to suggest more
      const existingLabels = this.currentChat?.labels || [];
      if (existingLabels.length > 0) return;

      if (!this.captainTasksEnabled || !this.isLabelSuggestionFeatureEnabled) {
        return;
      }

      this.labelSuggestions = await this.getLabelSuggestions();

      // once the labels are fetched, we need to scroll to bottom
      // but we need to wait for the DOM to be updated
      // so we use the nextTick method
      this.$nextTick(() => {
        // this param is added to route, telling the UI to navigate to the message
        // it is triggered by the SCROLL_TO_MESSAGE method
        // see setActiveChat on ConversationView.vue for more info
        const { messageId } = this.$route.query;

        // only trigger the scroll to bottom if the user has not scrolled
        // and there's no active messageId that is selected in view
        if (!messageId && !this.hasUserScrolled) {
          this.scrollToBottom();
        }
      });
    },
    isLabelSuggestionDismissed() {
      return LocalStorage.getFlag(
        LOCAL_STORAGE_KEYS.DISMISSED_LABEL_SUGGESTIONS,
        this.currentAccountId,
        this.currentChat.id
      );
    },
    fetchAllAttachmentsFromCurrentChat() {
      this.$store.dispatch('fetchAllAttachments', this.currentChat.id);
    },
    removeBusListeners() {
      emitter.off(BUS_EVENTS.SCROLL_TO_MESSAGE, this.onScrollToMessage);
      emitter.off(
        BUS_EVENTS.TOGGLE_MESSAGE_SELECTION_MODE,
        this.toggleSelectionMode
      );
    },
    onScrollToMessage({ messageId = '' } = {}) {
      this.$nextTick(() => {
        const messageElement = document.getElementById('message' + messageId);
        if (messageElement) {
          this.isProgrammaticScroll = true;
          messageElement.scrollIntoView({ behavior: 'smooth' });
          this.fetchPreviousMessages();
        } else {
          this.scrollToBottom();
        }
      });
      this.makeMessagesRead();
    },
    addScrollListener() {
      this.conversationPanel = this.$el.querySelector('.conversation-panel');
      this.setScrollParams();
      this.conversationPanel.addEventListener('scroll', this.handleScroll);
      this.$nextTick(() => this.scrollToBottom());
      this.isLoadingPrevious = false;
    },
    removeScrollListener() {
      this.conversationPanel.removeEventListener('scroll', this.handleScroll);
    },
    scrollToBottom() {
      this.isProgrammaticScroll = true;
      let relevantMessages = [];

      // label suggestions are not part of the messages list
      // so we need to handle them separately
      let labelSuggestions =
        this.conversationPanel.querySelector('.label-suggestion');

      // if there are unread messages, scroll to the first unread message
      if (this.unreadMessageCount > 0) {
        // capturing only the unread messages
        relevantMessages =
          this.conversationPanel.querySelectorAll('.message--unread');
      } else if (labelSuggestions) {
        // when scrolling to the bottom, the label suggestions is below the last message
        // so we scroll there if there are no unread messages
        // Unread messages always take the highest priority
        relevantMessages = [labelSuggestions];
      } else {
        // if there are no unread messages or label suggestion, scroll to the last message
        // capturing last message from the messages list
        relevantMessages = Array.from(
          this.conversationPanel.querySelectorAll('.message--read')
        ).slice(-1);
      }

      this.conversationPanel.scrollTop = calculateScrollTop(
        this.conversationPanel.scrollHeight,
        this.$el.scrollHeight,
        relevantMessages
      );
    },
    setScrollParams() {
      this.heightBeforeLoad = this.conversationPanel.scrollHeight;
      this.scrollTopBeforeLoad = this.conversationPanel.scrollTop;
    },

    async fetchPreviousMessages(scrollTop = 0) {
      this.setScrollParams();
      const shouldLoadMoreMessages =
        this.currentChat.dataFetched === true &&
        !this.listLoadingStatus &&
        !this.isLoadingPrevious;

      if (
        scrollTop < 100 &&
        !this.isLoadingPrevious &&
        shouldLoadMoreMessages
      ) {
        this.isLoadingPrevious = true;
        try {
          await this.$store.dispatch('fetchPreviousMessages', {
            conversationId: this.currentChat.id,
            before: this.currentChat.messages[0].id,
          });
          const heightDifference =
            this.conversationPanel.scrollHeight - this.heightBeforeLoad;
          this.conversationPanel.scrollTop =
            this.scrollTopBeforeLoad + heightDifference;
          this.setScrollParams();
        } catch (error) {
          // Ignore Error
        } finally {
          this.isLoadingPrevious = false;
        }
      }
    },

    handleScroll(e) {
      if (this.isProgrammaticScroll) {
        // Reset the flag
        this.isProgrammaticScroll = false;
        this.hasUserScrolled = false;
      } else {
        this.hasUserScrolled = true;
      }
      emitter.emit(BUS_EVENTS.ON_MESSAGE_LIST_SCROLL);
      this.fetchPreviousMessages(e.target.scrollTop);
    },

    makeMessagesRead() {
      this.$store.dispatch('markMessagesRead', { id: this.currentChat.id });
    },
    async handleMessageRetry(message) {
      if (!message) return;
      const payload = useSnakeCase(message);
      await this.$store.dispatch('sendMessageWithData', payload);
    },
    toggleReplyEditorSize() {
      this.resizableEditorWrapperRef?.toggleEditorExpand?.();
    },
    resetReplyEditorHeight() {
      this.resizableEditorWrapperRef?.resetEditorHeight?.();
    },
    // A ficha do cliente sempre é o contato da conversa nativa de origem -
    // resolve via store (não busca) pra garantir que é exatamente o mesmo
    // registro, no formato camelCase que formState.contact espera.
    //
    // Não concatena mais as mensagens selecionadas num texto só (ver
    // NewInternalTicket.vue) - passa a lista crua, na ordem cronológica já
    // calculada por selectedMessagesSorted, e quem cria as mensagens de
    // verdade (uma por uma, preservando tipo/remetente/anexo) é o backend
    // (Conversations::CopyMessagesService), depois que o ticket já existe.
    async handleCreateInternalTicketFromSelection() {
      if (!this.selectedCount) return;

      const messages = this.selectedMessagesSorted;

      const contactId = this.currentChat.meta?.sender?.id;
      let contact = null;
      if (contactId) {
        await this.$store.dispatch('contacts/show', { id: contactId });
        contact = this.$store.getters['contacts/getContactById'](contactId);
      }

      this.toggleSelectionMode();
      this.newInternalTicketRef?.open({
        selectedMessages: messages,
        sourceConversationId: this.currentChat.id,
        contact,
      });
    },
    handleAddSelectionToExistingTicket() {
      if (!this.selectedCount) return;

      const selectedIds = this.selectedMessagesSorted.map(
        message => message.id
      );
      this.toggleSelectionMode();
      this.$refs.addToExistingTicketRef?.open({
        sourceConversationId: this.currentChat.id,
        selectedIds,
        contactId: this.currentChat.meta?.sender?.id,
      });
    },
  },
};
</script>

<template>
  <div
    ref="messagesViewRef"
    class="flex flex-col justify-between flex-grow h-full min-w-0 m-0"
  >
    <div ref="topBannerRef" class="relative">
      <ConversationChecklists :key="currentChat.id" />
      <NextButton
        v-if="activityMessageCount"
        xs
        slate
        faded
        class="absolute top-full end-4 mt-2 z-10 shadow-sm"
        :icon="showActivities ? 'i-lucide-eye-off' : 'i-lucide-eye'"
        :label="
          showActivities
            ? $t('CONVERSATION.ACTIVITIES_TOGGLE.HIDE')
            : $t('CONVERSATION.ACTIVITIES_TOGGLE.SHOW', {
                count: activityMessageCount,
              })
        "
        @click="toggleActivities"
      />
      <Banner
        v-if="isInstagramRestrictionBannerVisible"
        color-scheme="warning"
        class="mx-2 mt-2 min-h-12 !h-auto rounded-lg"
        :banner-message="$t('CONVERSATION.INSTAGRAM_RESTRICTION_BANNER')"
        :href-link="instagramRestrictionStatusUrl"
        :href-link-text="$t('CONVERSATION.INSTAGRAM_RESTRICTION_STATUS_LINK')"
      />
      <Banner
        v-if="!currentChat.can_reply"
        color-scheme="alert"
        class="mx-2 mt-2 overflow-hidden rounded-lg"
        :banner-message="replyWindowBannerMessage"
        :href-link="replyWindowLink"
        :href-link-text="replyWindowLinkText"
      />
      <Banner
        v-if="hasDuplicateInstagramInbox"
        color-scheme="alert"
        class="mx-2 mt-2 overflow-hidden rounded-lg"
        :banner-message="$t('CONVERSATION.OLD_INSTAGRAM_INBOX_REPLY_BANNER')"
      />
    </div>
    <MessageList
      ref="conversationPanelRef"
      class="conversation-panel flex-shrink flex-grow basis-px flex flex-col overflow-y-auto relative h-full m-0 pb-4"
      :current-user-id="currentUserId"
      :first-unread-id="unReadMessages[0]?.id"
      :is-an-email-channel="isAnEmailChannel"
      :inbox-supports-reply-to="inboxSupportsReplyTo"
      :messages="getMessages"
      :selection-mode-active="isSelectionModeActive"
      :selected-message-ids="selectedMessageIds"
      @retry="handleMessageRetry"
      @toggle-select="toggleMessageSelection"
    >
      <template #beforeAll>
        <transition name="slide-up">
          <!-- eslint-disable-next-line vue/require-toggle-inside-transition -->
          <li
            class="min-h-[4rem] flex flex-shrink-0 flex-grow-0 items-center flex-auto justify-center max-w-full mt-0 mr-0 mb-1 ml-0 relative first:mt-auto last:mb-0"
          >
            <Spinner v-if="shouldShowSpinner" class="text-n-brand" />
          </li>
        </transition>
        <ReferralBubble v-if="referralData" :referral="referralData" />
      </template>
      <template #unreadBadge>
        <li
          v-show="unreadMessageCount != 0"
          class="list-none flex justify-center items-center"
        >
          <span
            class="shadow-lg rounded-full bg-n-brand text-white text-xs font-medium my-2.5 mx-auto px-2.5 py-1.5"
          >
            {{ unreadMessageLabel }}
          </span>
        </li>
      </template>
      <template #after>
        <ConversationLabelSuggestion
          v-if="shouldShowLabelSuggestions"
          :suggested-labels="labelSuggestions"
          :chat-labels="currentChat.labels"
          :conversation-id="currentChat.id"
        />
      </template>
    </MessageList>
    <div class="flex relative flex-col bg-n-surface-1">
      <div
        v-if="isSelectionModeActive"
        class="flex items-center justify-between gap-2 px-4 py-2 border-t border-n-weak bg-n-solid-2"
      >
        <div class="flex items-center gap-2 min-w-0">
          <span class="text-sm text-n-slate-11 truncate">
            {{
              $t('CONVERSATION.MESSAGE_SELECTION.COUNT', {
                count: selectedCount,
              })
            }}
          </span>
          <NextButton
            :label="$t('CONVERSATION.MESSAGE_SELECTION.CANCEL')"
            ghost
            sm
            @click="toggleSelectionMode"
          />
        </div>
        <div class="flex items-center gap-2 shrink-0">
          <NextButton
            :label="$t('CONVERSATION.MESSAGE_SELECTION.ADD_TO_TICKET')"
            faded
            sm
            :disabled="!selectedCount"
            @click="handleAddSelectionToExistingTicket"
          />
          <NextButton
            :label="$t('CONVERSATION.MESSAGE_SELECTION.CREATE_TICKET')"
            sm
            :disabled="!selectedCount"
            @click="handleCreateInternalTicketFromSelection"
          />
        </div>
      </div>
      <div
        v-if="isAnyoneTyping"
        class="absolute flex items-center w-full h-0 -top-7"
      >
        <div
          class="flex py-2 pr-4 pl-5 shadow-md rounded-full bg-white dark:bg-n-solid-3 text-n-slate-11 text-xs font-semibold my-2.5 mx-auto"
        >
          {{ typingUserNames }}
          <img
            class="w-6 ltr:ml-2 rtl:mr-2"
            src="assets/images/typing.gif"
            alt="Someone is typing"
          />
        </div>
      </div>
      <ResizableEditorWrapper
        ref="resizableEditorWrapperRef"
        :container-height="Math.max(0, containerHeight - topBannerHeight)"
      >
        <MessageEditBar v-if="editingMessage" />
        <ReplyBox v-else @toggle-editor-size="toggleReplyEditorSize" />
      </ResizableEditorWrapper>
    </div>
    <NewInternalTicket ref="newInternalTicketRef" />
    <AddToExistingTicket ref="addToExistingTicketRef" />
  </div>
</template>
