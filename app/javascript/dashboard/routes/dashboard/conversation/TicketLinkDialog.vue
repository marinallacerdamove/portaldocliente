<script setup>
import { ref, computed } from 'vue';
import { useRoute } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import ConversationApi from 'dashboard/api/conversations';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import ContactDetailsItem from './ContactDetailsItem.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const { t } = useI18n();
const store = useStore();
const route = useRoute();

const currentChat = useMapGetter('getSelectedChat');
const teams = useMapGetter('teams/getTeams');
const agentsList = useMapGetter('agents/getAgents');

const dialogRef = ref(null);
const linkMode = ref(null);
const internalTicketAgent = ref(null);
const internalTicketTeam = ref(null);
const internalTicketMessage = ref('');
const existingTicketQuery = ref('');
const existingTicketResults = ref([]);
const isSearchingExisting = ref(false);
const isLinkingExisting = ref(false);
const isCreatingInternalTicket = ref(false);

const canCreateInternalTicket = computed(
  () => !!internalTicketTeam.value && !!internalTicketMessage.value.trim()
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

const linkExistingTicket = async pickedSummary => {
  const current = currentChat.value;
  isLinkingExisting.value = true;
  try {
    // Search results don't include custom_attributes — fetch the full
    // record first so we don't clobber whatever it already has set.
    const { data: picked } = await ConversationApi.show(pickedSummary.id);

    if (linkMode.value === 'existingChild') {
      await store.dispatch('updateCustomAttributes', {
        conversationId: picked.id,
        customAttributes: {
          ...(picked.custom_attributes || {}),
          ticket_pai_id: String(current.id),
        },
      });
      const existing = (current.custom_attributes || {}).ticket_filhos_ids;
      const ids = existing ? existing.split(',') : [];
      if (!ids.includes(String(picked.id))) ids.push(String(picked.id));
      await store.dispatch('updateCustomAttributes', {
        conversationId: current.id,
        customAttributes: {
          ...(current.custom_attributes || {}),
          ticket_filhos_ids: ids.join(','),
        },
      });
    } else {
      await store.dispatch('updateCustomAttributes', {
        conversationId: current.id,
        customAttributes: {
          ...(current.custom_attributes || {}),
          ticket_pai_id: String(picked.id),
        },
      });
      const existing = (picked.custom_attributes || {}).ticket_filhos_ids;
      const ids = existing ? existing.split(',') : [];
      if (!ids.includes(String(current.id))) ids.push(String(current.id));
      await store.dispatch('updateCustomAttributes', {
        conversationId: picked.id,
        customAttributes: {
          ...(picked.custom_attributes || {}),
          ticket_filhos_ids: ids.join(','),
        },
      });
    }
    useAlert(t('TICKET_LINK_DIALOG.LINK_SUCCESS'));
    close();
  } catch (error) {
    useAlert(t('TICKET_LINK_DIALOG.LINK_ERROR'));
  } finally {
    isLinkingExisting.value = false;
  }
};

const onCreateInternalTicket = async () => {
  const targetTeam = internalTicketTeam.value;
  if (!targetTeam || !internalTicketMessage.value.trim()) return;

  const conv = currentChat.value;
  const accountId = route.params.accountId;
  const isParentMode = linkMode.value === 'newParent';
  const relationLabel = isParentMode ? 'pai' : 'filho';
  const protocolo = (conv.custom_attributes || {}).ticket_id_externo;
  const originalUrl = `${window.location.origin}/app/accounts/${accountId}/conversations/${conv.id}`;
  const content = [
    `Ticket ${relationLabel} para o time ${targetTeam.name}, a partir da conversa #${
      conv.id
    }${protocolo ? ` (Protocolo ${protocolo})` : ''}.`,
    `Conversa original: ${originalUrl}`,
    '',
    internalTicketMessage.value.trim(),
  ].join('\n');

  isCreatingInternalTicket.value = true;
  try {
    const data = await store.dispatch('contactConversations/create', {
      params: {
        inboxId: conv.inbox_id,
        contactId: conv.meta.sender.id,
        message: { content },
      },
    });

    await store.dispatch('assignTeam', {
      conversationId: data.id,
      teamId: targetTeam.id,
    });

    if (internalTicketAgent.value) {
      await store.dispatch('assignAgent', {
        conversationId: data.id,
        agentId: internalTicketAgent.value.id,
      });
    }

    if (isParentMode) {
      await store.dispatch('updateCustomAttributes', {
        conversationId: conv.id,
        customAttributes: {
          ...(conv.custom_attributes || {}),
          ticket_pai_id: String(data.id),
        },
      });
      await store.dispatch('updateCustomAttributes', {
        conversationId: data.id,
        customAttributes: {
          ...(data.custom_attributes || {}),
          ticket_filhos_ids: String(conv.id),
        },
      });
    } else {
      await store.dispatch('updateCustomAttributes', {
        conversationId: data.id,
        customAttributes: {
          ...(data.custom_attributes || {}),
          ticket_pai_id: String(conv.id),
        },
      });

      const existingChildren = (conv.custom_attributes || {}).ticket_filhos_ids;
      const childIds = existingChildren ? existingChildren.split(',') : [];
      childIds.push(String(data.id));
      await store.dispatch('updateCustomAttributes', {
        conversationId: conv.id,
        customAttributes: {
          ...(conv.custom_attributes || {}),
          ticket_filhos_ids: childIds.join(','),
        },
      });
    }

    await store.dispatch('createPendingMessageAndSend', {
      conversationId: conv.id,
      message: `Ticket ${relationLabel} criado para o time ${targetTeam.name}: ${window.location.origin}/app/accounts/${accountId}/conversations/${data.id}`,
      private: true,
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
    :title="linkFormTitle"
    width="sm"
    :show-confirm-button="false"
    :cancel-button-label="$t('TICKET_LINK_DIALOG.CLOSE_BUTTON')"
    @close="reset"
  >
    <div v-if="showCreateForm" class="flex flex-col gap-2 w-full">
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
          {{ result.contact ? result.contact.name : '' }} —
          {{ (result.message && result.message.content) || '' }}
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
