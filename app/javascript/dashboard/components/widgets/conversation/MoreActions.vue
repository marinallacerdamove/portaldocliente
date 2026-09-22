<script setup>
import { computed, onUnmounted, ref } from 'vue';
import { useToggle } from '@vueuse/core';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';
import EmailTranscriptModal from './EmailTranscriptModal.vue';
import ResolveAction from '../../buttons/ResolveAction.vue';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import TicketLinkDialog from 'dashboard/routes/dashboard/conversation/TicketLinkDialog.vue';

import {
  CMD_MUTE_CONVERSATION,
  CMD_SEND_TRANSCRIPT,
  CMD_UNMUTE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';
import { BUS_EVENTS } from 'shared/constants/busEvents';

// No props needed as we're getting currentChat from the store directly
const store = useStore();
const { t } = useI18n();

const [showEmailActionsModal, toggleEmailModal] = useToggle(false);
const [showActionsDropdown, toggleDropdown] = useToggle(false);
const ticketLinkDialogRef = ref(null);

const currentChat = computed(() => store.getters.getSelectedChat);

const actionMenuSections = computed(() => {
  const generalItems = [];

  if (!currentChat.value.muted) {
    generalItems.push({
      icon: 'i-lucide-volume-off',
      label: t('CONTACT_PANEL.MUTE_CONTACT'),
      action: 'mute',
      value: 'mute',
    });
  } else {
    generalItems.push({
      icon: 'i-lucide-volume-1',
      label: t('CONTACT_PANEL.UNMUTE_CONTACT'),
      action: 'unmute',
      value: 'unmute',
    });
  }

  generalItems.push({
    icon: 'i-lucide-share',
    label: t('CONTACT_PANEL.SEND_TRANSCRIPT'),
    action: 'send_transcript',
    value: 'send_transcript',
  });

  generalItems.push({
    icon: 'i-lucide-list-checks',
    label: t('CONTACT_PANEL.SELECT_MESSAGES'),
    action: 'select_messages',
    value: 'select_messages',
  });

  return [
    { title: '', items: generalItems },
    {
      title: t('TICKET_LINK_DIALOG.MENU.PARENT_SECTION'),
      items: [
        {
          icon: 'i-lucide-git-branch-plus',
          label: t('TICKET_LINK_DIALOG.MENU.CREATE_NEW'),
          action: 'ticket_link',
          value: 'newParent',
        },
        {
          icon: 'i-lucide-link',
          label: t('TICKET_LINK_DIALOG.MENU.RELATE_EXISTING'),
          action: 'ticket_link',
          value: 'existingParent',
        },
      ],
    },
    {
      title: t('TICKET_LINK_DIALOG.MENU.CHILD_SECTION'),
      items: [
        {
          icon: 'i-lucide-git-branch-plus',
          label: t('TICKET_LINK_DIALOG.MENU.CREATE_NEW'),
          action: 'ticket_link',
          value: 'newChild',
        },
        {
          icon: 'i-lucide-link',
          label: t('TICKET_LINK_DIALOG.MENU.RELATE_EXISTING'),
          action: 'ticket_link',
          value: 'existingChild',
        },
      ],
    },
  ];
});

const handleActionClick = ({ action, value }) => {
  toggleDropdown(false);

  if (action === 'mute') {
    store.dispatch('muteConversation', currentChat.value.id);
    useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
  } else if (action === 'unmute') {
    store.dispatch('unmuteConversation', currentChat.value.id);
    useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
  } else if (action === 'send_transcript') {
    toggleEmailModal();
  } else if (action === 'select_messages') {
    emitter.emit(BUS_EVENTS.TOGGLE_MESSAGE_SELECTION_MODE);
  } else if (action === 'ticket_link') {
    ticketLinkDialogRef.value?.open(value);
  }
};

// These functions are needed for the event listeners
const mute = () => {
  store.dispatch('muteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
};

const unmute = () => {
  store.dispatch('unmuteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
};

emitter.on(CMD_MUTE_CONVERSATION, mute);
emitter.on(CMD_UNMUTE_CONVERSATION, unmute);
emitter.on(CMD_SEND_TRANSCRIPT, toggleEmailModal);

onUnmounted(() => {
  emitter.off(CMD_MUTE_CONVERSATION, mute);
  emitter.off(CMD_UNMUTE_CONVERSATION, unmute);
  emitter.off(CMD_SEND_TRANSCRIPT, toggleEmailModal);
});
</script>

<template>
  <div class="relative flex items-center gap-2 actions--container">
    <ResolveAction
      :conversation-id="currentChat.id"
      :status="currentChat.status"
    />
    <div
      v-on-clickaway="() => toggleDropdown(false)"
      class="relative flex items-center group"
    >
      <ButtonV4
        v-tooltip="$t('CONVERSATION.HEADER.MORE_ACTIONS')"
        size="sm"
        variant="ghost"
        color="slate"
        icon="i-lucide-more-vertical"
        class="rounded-md group-hover:bg-n-alpha-2"
        @click="toggleDropdown()"
      />
      <DropdownMenu
        v-if="showActionsDropdown"
        :menu-sections="actionMenuSections"
        class="mt-1 ltr:right-0 rtl:left-0 top-full"
        @action="handleActionClick"
      />
    </div>
    <EmailTranscriptModal
      v-if="showEmailActionsModal"
      :show="showEmailActionsModal"
      :current-chat="currentChat"
      @cancel="toggleEmailModal"
    />
    <TicketLinkDialog ref="ticketLinkDialogRef" />
  </div>
</template>
