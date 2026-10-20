<script setup>
import { ref, computed } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useEmitter } from 'dashboard/composables/emitter';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useConversationRequiredAttributes } from 'dashboard/composables/useConversationRequiredAttributes';
import { useResolveRequirements } from 'dashboard/composables/useResolveRequirements';
import { statusChangeErrorMessage } from 'dashboard/helper/statusChangeError';
import { shouldOfferPortalTicket } from 'dashboard/helper/portalTicketOffer';
import {
  CRIAR_TICKET_PORTAL_ATTRIBUTE_KEY,
  CRIAR_TICKET_PORTAL_NAO,
  CRIAR_TICKET_PORTAL_SIM,
} from 'dashboard/constants/ticketDetailAttributes';

import WootDropdownItem from 'shared/components/ui/dropdown/DropdownItem.vue';
import WootDropdownMenu from 'shared/components/ui/dropdown/DropdownMenu.vue';
import wootConstants from 'dashboard/constants/globals';
import {
  CMD_REOPEN_CONVERSATION,
  CMD_RESOLVE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

import ButtonGroup from 'dashboard/components-next/buttonGroup/ButtonGroup.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ConversationResolveAttributesModal from 'dashboard/components-next/ConversationWorkflow/ConversationResolveAttributesModal.vue';
import ResolvePortalTicketDialog from 'dashboard/components-next/ConversationWorkflow/ResolvePortalTicketDialog.vue';

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();
const { checkMissingAttributes } = useConversationRequiredAttributes();

const { missingFor } = useResolveRequirements();

const arrowDownButtonRef = ref(null);
const isLoading = ref(false);
const resolveAttributesModalRef = ref(null);
const portalTicketDialogRef = ref(null);
// PATCH LOCAL (fork) - atributos que vão junto com esta resolução (ex.: status
// "Fechado" escolhido no cabeçalho), gravados no mesmo update do motivo.
const pendingExtraAttributes = ref({});

const [showActionsDropdown, toggleDropdown] = useToggle();
const closeDropdown = () => toggleDropdown(false);
const openDropdown = () => toggleDropdown(true);

const currentChat = computed(() => getters.getSelectedChat.value);
const isOpen = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.OPEN
);
const isPending = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.PENDING
);
const isResolved = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.RESOLVED
);
const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);

const showAdditionalActions = computed(
  () => !isPending.value && !isSnoozed.value
);

const showOpenButton = computed(() => {
  return isPending.value || isSnoozed.value;
});

const getConversationParams = () => {
  const allConversations = document.querySelectorAll(
    '.conversations-list .conversation'
  );

  const activeConversation = document.querySelector(
    'div.conversations-list div.conversation.active'
  );
  const activeConversationIndex = [...allConversations].indexOf(
    activeConversation
  );
  const lastConversationIndex = allConversations.length - 1;

  return {
    all: allConversations,
    activeIndex: activeConversationIndex,
    lastIndex: lastConversationIndex,
  };
};

const openSnoozeModal = () => {
  const ninja = document.querySelector('ninja-keys');
  ninja.open({ parent: 'snooze_conversation' });
};

const toggleStatus = (
  status,
  snoozedUntil,
  customAttributes = null,
  conversationId = currentChat.value.id
) => {
  closeDropdown();
  isLoading.value = true;

  const payload = {
    conversationId,
    status,
    snoozedUntil,
  };

  if (customAttributes) {
    payload.customAttributes = customAttributes;
  }

  store
    .dispatch('toggleStatus', payload)
    .then(() => useAlert(t('CONVERSATION.CHANGE_STATUS')))
    .catch(error => useAlert(statusChangeErrorMessage(error, t)))
    .finally(() => {
      isLoading.value = false;
    });
};

const handleResolveWithAttributes = ({ attributes, context }) => {
  if (context) {
    toggleStatus(
      wootConstants.STATUS_TYPE.RESOLVED,
      context.snoozedUntil,
      { ...pendingExtraAttributes.value, ...attributes },
      context.id
    );
  }
};

const onCmdOpenConversation = () => {
  toggleStatus(wootConstants.STATUS_TYPE.OPEN);
};

const onCmdResolveConversation = async ({ attributes = {} } = {}) => {
  // A conversa em que o agente clicou: com a pergunta do Portal aberta (ou o
  // atalho que já passa pra próxima) a selecionada pode mudar antes de encerrar.
  const target = currentChat.value;
  pendingExtraAttributes.value = attributes;
  const requirements = await missingFor(target, {
    priority: t('CONVERSATION.PRIORITY.TITLE'),
    assignee: t('CONVERSATION_SIDEBAR.ASSIGNEE_LABEL'),
    team: t('CONVERSATION_SIDEBAR.TEAM_LABEL'),
  });
  if (requirements.actions.length) {
    useAlert(
      t('CONVERSATION.RESOLVE_REQUIRED_ACTIONS', {
        fields: requirements.actions.map(item => item.label).join(', '),
      })
    );
    return;
  }
  if (requirements.customFields.length) {
    useAlert(
      t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.MISSING_ON_RESOLVE', {
        fields: requirements.customFields.join(', '),
      })
    );
    return;
  }
  // Conversa de WhatsApp sem ticket: o agente decide se vira ticket no Portal.
  // Fechar a pergunta (X/Esc) desiste de encerrar.
  if (shouldOfferPortalTicket(target)) {
    const createTicket = await portalTicketDialogRef.value?.ask(
      target.meta?.sender?.name
    );
    if (createTicket === null) return;
    pendingExtraAttributes.value = {
      ...pendingExtraAttributes.value,
      [CRIAR_TICKET_PORTAL_ATTRIBUTE_KEY]: createTicket
        ? CRIAR_TICKET_PORTAL_SIM
        : CRIAR_TICKET_PORTAL_NAO,
    };
  }
  const currentCustomAttributes = target.custom_attributes || {};
  const { missing } = checkMissingAttributes(currentCustomAttributes);
  const { closeReason } = requirements;
  if (
    closeReason &&
    !missing.some(attribute => attribute.value === closeReason.value)
  ) {
    missing.push(closeReason);
  }

  if (missing.length) {
    const conversationContext = {
      id: target.id,
      snoozedUntil: null,
    };
    resolveAttributesModalRef.value?.open(
      missing,
      currentCustomAttributes,
      conversationContext
    );
  } else if (Object.keys(pendingExtraAttributes.value).length) {
    toggleStatus(
      wootConstants.STATUS_TYPE.RESOLVED,
      null,
      pendingExtraAttributes.value,
      target.id
    );
  } else {
    toggleStatus(wootConstants.STATUS_TYPE.RESOLVED, null, null, target.id);
  }
};

const keyboardEvents = {
  'Alt+KeyM': {
    action: () => arrowDownButtonRef.value?.$el.click(),
    allowOnFocusedInput: true,
  },
  'Alt+KeyE': {
    action: async event => {
      // Chrome on Windows treats Alt+E as a legacy shortcut for its own
      // menu (Alt+E / Alt+F both open "Customize and control Google
      // Chrome"). Without preventDefault, our resolve action still runs,
      // but Chrome's menu also opens on top of it.
      event.preventDefault();
      onCmdResolveConversation();
    },
  },
  '$mod+Alt+KeyE': {
    action: async event => {
      const { all, activeIndex, lastIndex } = getConversationParams();
      onCmdResolveConversation();

      if (activeIndex < lastIndex) {
        all[activeIndex + 1].click();
      } else if (all.length > 1) {
        all[0].click();
        document.querySelector('.conversations-list').scrollTop = 0;
      }
      event.preventDefault();
    },
  },
};

useKeyboardEvents(keyboardEvents);

useEmitter(CMD_REOPEN_CONVERSATION, onCmdOpenConversation);
useEmitter(CMD_RESOLVE_CONVERSATION, onCmdResolveConversation);
</script>

<template>
  <div class="flex relative justify-end items-center resolve-actions">
    <ButtonGroup
      class="flex-shrink-0 rounded-lg shadow outline-1 outline"
      :class="!showOpenButton ? 'outline-n-container' : 'outline-transparent'"
    >
      <Button
        v-if="isOpen"
        :label="t('CONVERSATION.HEADER.RESOLVE_ACTION')"
        size="sm"
        color="slate"
        no-animation
        class="ltr:rounded-r-none rtl:rounded-l-none !outline-0"
        :is-loading="isLoading"
        @click="() => onCmdResolveConversation()"
      />
      <Button
        v-else-if="isResolved"
        :label="t('CONVERSATION.HEADER.REOPEN_ACTION')"
        size="sm"
        color="slate"
        no-animation
        class="ltr:rounded-r-none rtl:rounded-l-none !outline-0"
        :is-loading="isLoading"
        @click="onCmdOpenConversation"
      />
      <Button
        v-else-if="showOpenButton"
        :label="t('CONVERSATION.HEADER.OPEN_ACTION')"
        size="sm"
        color="slate"
        no-animation
        :is-loading="isLoading"
        @click="onCmdOpenConversation"
      />
      <Button
        v-if="showAdditionalActions"
        ref="arrowDownButtonRef"
        icon="i-lucide-chevron-down"
        :disabled="isLoading"
        size="sm"
        no-animation
        class="ltr:rounded-l-none rtl:rounded-r-none !outline-0"
        color="slate"
        trailing-icon
        @click="openDropdown"
      />
    </ButtonGroup>
    <div
      v-if="showActionsDropdown"
      v-on-clickaway="closeDropdown"
      class="border rounded-lg shadow-lg border-n-strong dark:border-n-strong box-content p-2 w-fit z-10 bg-n-alpha-3 backdrop-blur-[100px] absolute block left-auto top-full mt-0.5 start-0 xl:start-auto xl:end-0 max-w-[12.5rem] min-w-[9.75rem] [&_ul>li]:mb-0"
    >
      <WootDropdownMenu class="mb-0">
        <WootDropdownItem v-if="!isPending">
          <Button
            :label="t('CONVERSATION.RESOLVE_DROPDOWN.SNOOZE_UNTIL')"
            ghost
            slate
            sm
            start
            icon="i-lucide-alarm-clock-minus"
            class="w-full"
            @click="() => openSnoozeModal()"
          />
        </WootDropdownItem>
        <WootDropdownItem v-if="!isPending">
          <Button
            :label="t('CONVERSATION.RESOLVE_DROPDOWN.MARK_PENDING')"
            ghost
            slate
            sm
            start
            icon="i-lucide-circle-dot-dashed"
            class="w-full"
            @click="() => toggleStatus(wootConstants.STATUS_TYPE.PENDING)"
          />
        </WootDropdownItem>
      </WootDropdownMenu>
    </div>
    <ConversationResolveAttributesModal
      ref="resolveAttributesModalRef"
      @submit="handleResolveWithAttributes"
    />
    <ResolvePortalTicketDialog ref="portalTicketDialogRef" />
  </div>
</template>
