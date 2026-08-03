<!-- eslint-disable vue/v-slot-style -->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ConversationApi from 'dashboard/api/conversations';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import ContactDetailsItem from './ContactDetailsItem.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

export default {
  components: {
    MultiselectDropdown,
    ContactDetailsItem,
    NextButton,
    Dialog,
  },
  data() {
    return {
      linkMode: null,
      internalTicketAgent: null,
      internalTicketTeam: null,
      internalTicketMessage: '',
      existingTicketQuery: '',
      existingTicketResults: [],
      isSearchingExisting: false,
      isLinkingExisting: false,
      isCreatingInternalTicket: false,
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      teams: 'teams/getTeams',
      agentsList: 'agents/getAgents',
    }),
    canCreateInternalTicket() {
      return !!this.internalTicketTeam && !!this.internalTicketMessage.trim();
    },
    showCreateForm() {
      return this.linkMode === 'newChild' || this.linkMode === 'newParent';
    },
    showExistingSearch() {
      return (
        this.linkMode === 'existingChild' || this.linkMode === 'existingParent'
      );
    },
    linkFormTitle() {
      const labels = {
        newChild: 'Criar ticket filho',
        newParent: 'Criar ticket pai',
        existingChild: 'Relacionar ticket filho existente',
        existingParent: 'Relacionar ticket pai existente',
      };
      return labels[this.linkMode] || 'Ticket interno';
    },
  },
  methods: {
    open(mode) {
      this.linkMode = mode;
      this.$refs.dialogRef?.open();
    },
    close() {
      this.$refs.dialogRef?.close();
    },
    reset() {
      this.linkMode = null;
      this.internalTicketAgent = null;
      this.internalTicketTeam = null;
      this.internalTicketMessage = '';
      this.existingTicketQuery = '';
      this.existingTicketResults = [];
    },
    onSelectInternalTicketAgent(selectedAgent) {
      this.internalTicketAgent = selectedAgent;

      const agentTeamIds = selectedAgent?.team_ids || [];
      const matchingTeam = this.teams.find(team =>
        agentTeamIds.includes(team.id)
      );
      if (matchingTeam) {
        this.internalTicketTeam = matchingTeam;
      }
    },

    async searchExistingTicket() {
      if (!this.existingTicketQuery.trim()) {
        this.existingTicketResults = [];
        return;
      }
      this.isSearchingExisting = true;
      try {
        await this.$store.dispatch('conversationSearch/conversationSearch', {
          q: this.existingTicketQuery.trim(),
        });
        this.existingTicketResults = this.$store.getters[
          'conversationSearch/getConversationRecords'
        ].filter(result => result.id !== this.currentChat.id);
      } finally {
        this.isSearchingExisting = false;
      }
    },

    async linkExistingTicket(pickedSummary) {
      const current = this.currentChat;
      this.isLinkingExisting = true;
      try {
        // Search results don't include custom_attributes — fetch the full
        // record first so we don't clobber whatever it already has set.
        const { data: picked } = await ConversationApi.show(pickedSummary.id);

        if (this.linkMode === 'existingChild') {
          await this.$store.dispatch('updateCustomAttributes', {
            conversationId: picked.id,
            customAttributes: {
              ...(picked.custom_attributes || {}),
              ticket_pai_id: String(current.id),
            },
          });
          const existing = (current.custom_attributes || {}).ticket_filhos_ids;
          const ids = existing ? existing.split(',') : [];
          if (!ids.includes(String(picked.id))) ids.push(String(picked.id));
          await this.$store.dispatch('updateCustomAttributes', {
            conversationId: current.id,
            customAttributes: {
              ...(current.custom_attributes || {}),
              ticket_filhos_ids: ids.join(','),
            },
          });
        } else {
          await this.$store.dispatch('updateCustomAttributes', {
            conversationId: current.id,
            customAttributes: {
              ...(current.custom_attributes || {}),
              ticket_pai_id: String(picked.id),
            },
          });
          const existing = (picked.custom_attributes || {}).ticket_filhos_ids;
          const ids = existing ? existing.split(',') : [];
          if (!ids.includes(String(current.id))) ids.push(String(current.id));
          await this.$store.dispatch('updateCustomAttributes', {
            conversationId: picked.id,
            customAttributes: {
              ...(picked.custom_attributes || {}),
              ticket_filhos_ids: ids.join(','),
            },
          });
        }
        useAlert('Vínculo criado!');
        this.close();
      } catch (error) {
        useAlert('Erro ao vincular o ticket.');
      } finally {
        this.isLinkingExisting = false;
      }
    },

    async onCreateInternalTicket() {
      const targetTeam = this.internalTicketTeam;
      if (!targetTeam || !this.internalTicketMessage.trim()) return;

      const conv = this.currentChat;
      const accountId = this.$route.params.accountId;
      const isParentMode = this.linkMode === 'newParent';
      const relationLabel = isParentMode ? 'pai' : 'filho';
      const protocolo = (conv.custom_attributes || {}).ticket_id_externo;
      const originalUrl = `${window.location.origin}/app/accounts/${accountId}/conversations/${conv.id}`;
      const content = [
        `Ticket ${relationLabel} para o time ${targetTeam.name}, a partir da conversa #${
          conv.id
        }${protocolo ? ` (Protocolo ${protocolo})` : ''}.`,
        `Conversa original: ${originalUrl}`,
        '',
        this.internalTicketMessage.trim(),
      ].join('\n');

      this.isCreatingInternalTicket = true;
      try {
        const data = await this.$store.dispatch('contactConversations/create', {
          params: {
            inboxId: conv.inbox_id,
            contactId: conv.meta.sender.id,
            message: { content },
          },
        });

        await this.$store.dispatch('assignTeam', {
          conversationId: data.id,
          teamId: targetTeam.id,
        });

        if (this.internalTicketAgent) {
          await this.$store.dispatch('assignAgent', {
            conversationId: data.id,
            agentId: this.internalTicketAgent.id,
          });
        }

        if (isParentMode) {
          await this.$store.dispatch('updateCustomAttributes', {
            conversationId: conv.id,
            customAttributes: {
              ...(conv.custom_attributes || {}),
              ticket_pai_id: String(data.id),
            },
          });
          await this.$store.dispatch('updateCustomAttributes', {
            conversationId: data.id,
            customAttributes: {
              ...(data.custom_attributes || {}),
              ticket_filhos_ids: String(conv.id),
            },
          });
        } else {
          await this.$store.dispatch('updateCustomAttributes', {
            conversationId: data.id,
            customAttributes: {
              ...(data.custom_attributes || {}),
              ticket_pai_id: String(conv.id),
            },
          });

          const existingChildren = (conv.custom_attributes || {}).ticket_filhos_ids;
          const childIds = existingChildren ? existingChildren.split(',') : [];
          childIds.push(String(data.id));
          await this.$store.dispatch('updateCustomAttributes', {
            conversationId: conv.id,
            customAttributes: {
              ...(conv.custom_attributes || {}),
              ticket_filhos_ids: childIds.join(','),
            },
          });
        }

        await this.$store.dispatch('createPendingMessageAndSend', {
          conversationId: conv.id,
          message: `Ticket ${relationLabel} criado para o time ${targetTeam.name}: ${window.location.origin}/app/accounts/${accountId}/conversations/${data.id}`,
          private: true,
        });

        useAlert(`Ticket ${relationLabel} criado!`, {
          type: 'link',
          to: `/app/accounts/${accountId}/conversations/${data.id}`,
          message: 'Ver ticket',
        });

        this.close();
      } catch (error) {
        useAlert('Erro ao criar o ticket interno.');
      } finally {
        this.isCreatingInternalTicket = false;
      }
    },
  },
};
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="linkFormTitle"
    width="sm"
    :show-confirm-button="false"
    cancel-button-label="Fechar"
    @close="reset"
  >
    <div v-if="showCreateForm" class="flex flex-col gap-2 w-full">
      <div>
        <ContactDetailsItem compact title="Agente" />
        <MultiselectDropdown
          :options="agentsList"
          :selected-item="internalTicketAgent"
          multiselector-title="Agente"
          multiselector-placeholder="Selecione"
          no-search-result="Nenhum agente encontrado"
          input-placeholder="Buscar agente"
          @select="onSelectInternalTicketAgent"
        />
      </div>
      <div>
        <ContactDetailsItem compact title="Time" />
        <MultiselectDropdown
          :options="teams"
          :selected-item="internalTicketTeam"
          show-emoji-icon
          multiselector-title="Time"
          multiselector-placeholder="Selecione"
          no-search-result="Nenhum time encontrado"
          input-placeholder="Buscar time"
          @select="internalTicketTeam = $event"
        />
      </div>
      <textarea
        v-model="internalTicketMessage"
        rows="3"
        placeholder="Descreva o ticket..."
        class="w-full p-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
      />
      <NextButton
        size="sm"
        justify="center"
        class="w-full"
        icon="i-lucide-git-branch-plus"
        :is-loading="isCreatingInternalTicket"
        :disabled="!canCreateInternalTicket"
        label="Criar ticket interno"
        @click="onCreateInternalTicket"
      />
    </div>

    <div v-else-if="showExistingSearch" class="flex flex-col gap-2 w-full">
      <div class="flex gap-2">
        <input
          v-model="existingTicketQuery"
          type="text"
          placeholder="Buscar por protocolo, assunto, contato..."
          class="flex-1 h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
          @keyup.enter="searchExistingTicket"
        />
        <NextButton
          size="sm"
          label="Buscar"
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
        Nenhum resultado
      </p>
    </div>
  </Dialog>
</template>
