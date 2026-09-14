<!-- eslint-disable vue/v-slot-style -->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useAgentsList } from 'dashboard/composables/useAgentsList';
import ContactDetailsItem from './ContactDetailsItem.vue';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import ConversationLabels from './labels/LabelBox.vue';
import CustomAttribute from 'dashboard/components/CustomAttribute.vue';
import CustomAttributes from './customAttributes/CustomAttributes.vue';
import LinkedTicketCard from './LinkedTicketCard.vue';
import { PORTAL_INFO_ATTRIBUTE_KEYS } from 'dashboard/constants/ticketDetailAttributes';
import { CONVERSATION_PRIORITY } from '../../../../shared/constants/messages';
import { CONVERSATION_EVENTS } from '../../../helper/AnalyticsHelper/events';
import { useTrack } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    ContactDetailsItem,
    MultiselectDropdown,
    ConversationLabels,
    CustomAttribute,
    CustomAttributes,
    LinkedTicketCard,
    NextButton,
  },
  props: {
    conversationId: {
      type: [Number, String],
      required: true,
    },
  },
  setup() {
    const { agentsList } = useAgentsList(true, { includeAgentBots: true });
    return {
      agentsList,
    };
  },
  data() {
    return {
      priorityOptions: [
        {
          id: null,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.NONE'),
          icon: 'i-woot-priority-empty',
        },
        {
          id: CONVERSATION_PRIORITY.URGENT,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.URGENT'),
          icon: 'i-woot-priority-urgent',
        },
        {
          id: CONVERSATION_PRIORITY.HIGH,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.HIGH'),
          icon: 'i-woot-priority-high',
        },
        {
          id: CONVERSATION_PRIORITY.MEDIUM,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.MEDIUM'),
          icon: 'i-woot-priority-medium',
        },
        {
          id: CONVERSATION_PRIORITY.LOW,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.LOW'),
          icon: 'i-woot-priority-low',
        },
      ],
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      currentUser: 'getCurrentUser',
      teams: 'teams/getTeams',
      getAttributesByModel: 'attributes/getAttributesByModel',
    }),
    servicoDefinition() {
      return this.getAttributesByModel('conversation_attribute').find(
        attr => attr.attribute_key === 'servico'
      );
    },
    servicoOptions() {
      const values = this.servicoDefinition
        ? this.servicoDefinition.attribute_values
        : [];
      return [
        { id: '', name: this.$t('CONVERSATION.PRIORITY.OPTIONS.NONE') },
        ...(values || []).map(value => ({ id: value, name: value })),
      ];
    },
    categoriaDefinition() {
      return this.getAttributesByModel('conversation_attribute').find(
        attr => attr.attribute_key === 'categoria'
      );
    },
    categoriaValue() {
      return (this.currentChat.custom_attributes || {}).categoria || '';
    },
    hasAnAssignedTeam() {
      return !!this.currentChat?.meta?.team;
    },
    teamsList() {
      if (this.hasAnAssignedTeam) {
        return [
          { id: 0, name: this.$t('TEAMS_SETTINGS.LIST.NONE') },
          ...this.teams,
        ];
      }
      return this.teams;
    },
    assignedAgent: {
      get() {
        const assignee = this.currentChat.meta.assignee;
        return (
          assignee && {
            ...assignee,
            assignee_type: this.currentChat.meta.assignee_type || 'User',
          }
        );
      },
      set(agent) {
        const agentId = agent ? agent.id : null;
        const assigneeType = agent ? agent.assignee_type || 'User' : null;
        this.$store.dispatch('setCurrentChatAssignee', {
          conversationId: this.currentChat.id,
          assignee: agent,
          assigneeType,
        });
        this.$store
          .dispatch('assignAgent', {
            conversationId: this.currentChat.id,
            agentId,
            assigneeType,
          })
          .then(() => {
            useAlert(this.$t('CONVERSATION.CHANGE_AGENT'));
          });
      },
    },
    assignedTeam: {
      get() {
        return this.currentChat.meta.team;
      },
      set(team) {
        const conversationId = this.currentChat.id;
        const teamId = team ? team.id : 0;
        this.$store.dispatch('setCurrentChatTeam', { team, conversationId });
        this.$store
          .dispatch('assignTeam', { conversationId, teamId })
          .then(() => {
            useAlert(this.$t('CONVERSATION.CHANGE_TEAM'));
          });
      },
    },
    assignedPriority: {
      get() {
        const selectedOption = this.priorityOptions.find(
          opt => opt.id === this.currentChat.priority
        );

        return selectedOption || this.priorityOptions[0];
      },
      set(priorityItem) {
        const conversationId = this.currentChat.id;
        const oldValue = this.currentChat?.priority;
        const priority = priorityItem.id;

        this.$store.dispatch('setCurrentChatPriority', {
          priority,
          conversationId,
        });
        this.$store
          .dispatch('assignPriority', { conversationId, priority })
          .then(() => {
            useTrack(CONVERSATION_EVENTS.CHANGE_PRIORITY, {
              oldValue,
              newValue: priority,
              from: 'Conversation Sidebar',
            });
            useAlert(
              this.$t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SUCCESSFUL', {
                priority: priorityItem.name,
                conversationId,
              })
            );
          });
      },
    },
    assignedServico: {
      get() {
        const current =
          (this.currentChat.custom_attributes || {}).servico || '';
        return (
          this.servicoOptions.find(opt => opt.id === current) ||
          this.servicoOptions[0]
        );
      },
      set(item) {
        const conversationId = this.currentChat.id;
        const updatedAttributes = {
          ...(this.currentChat.custom_attributes || {}),
        };
        if (item && item.id) {
          updatedAttributes.servico = item.id;
        } else {
          delete updatedAttributes.servico;
        }
        this.$store
          .dispatch('updateCustomAttributes', {
            conversationId,
            customAttributes: updatedAttributes,
          })
          .then(() => {
            useAlert(this.$t('CUSTOM_ATTRIBUTES.FORM.UPDATE.SUCCESS'));
          });
      },
    },
    ticketPaiId() {
      return (this.currentChat.custom_attributes || {}).ticket_pai_id || null;
    },
    ticketFilhosIds() {
      const raw = (this.currentChat.custom_attributes || {}).ticket_filhos_ids;
      return raw ? raw.split(',').filter(Boolean) : [];
    },
    portalInfoAttributeKeys() {
      return PORTAL_INFO_ATTRIBUTE_KEYS;
    },
    // Só mostra o bloco "Informações do Portal do Cliente" quando pelo menos
    // um desses campos veio preenchido de verdade - ticket criado direto no
    // Chatwoot (ticket interno) nunca tem nenhum, e mostrar tudo vazio só
    // polui a tela.
    hasPortalInfo() {
      const attrs = this.currentChat.custom_attributes || {};
      return PORTAL_INFO_ATTRIBUTE_KEYS.some(
        key =>
          attrs[key] !== undefined && attrs[key] !== null && attrs[key] !== ''
      );
    },
    showSelfAssign() {
      if (!this.assignedAgent) {
        return true;
      }
      if (
        this.assignedAgent.id !== this.currentUser.id ||
        (this.assignedAgent.assignee_type || 'User') !== 'User'
      ) {
        return true;
      }
      return false;
    },
  },
  methods: {
    onSelfAssign() {
      const {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        avatar_url,
      } = this.currentUser;
      const selfAssign = {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        thumbnail: avatar_url,
      };
      this.assignedAgent = selfAssign;
    },
    onClickAssignAgent(selectedItem) {
      if (
        this.assignedAgent?.id === selectedItem.id &&
        (this.assignedAgent?.assignee_type || 'User') ===
          (selectedItem.assignee_type || 'User')
      ) {
        this.assignedAgent = null;
      } else {
        this.assignedAgent = selectedItem;
      }
    },

    onClickAssignTeam(selectedItemTeam) {
      if (this.assignedTeam && this.assignedTeam.id === selectedItemTeam.id) {
        this.assignedTeam = null;
      } else {
        this.assignedTeam = selectedItemTeam;
      }
    },

    onClickAssignPriority(selectedPriorityItem) {
      const isSamePriority =
        this.assignedPriority &&
        this.assignedPriority.id === selectedPriorityItem.id;

      this.assignedPriority = isSamePriority
        ? this.priorityOptions[0]
        : selectedPriorityItem;
    },

    onClickAssignServico(selectedItem) {
      const isSame =
        this.assignedServico && this.assignedServico.id === selectedItem.id;

      this.assignedServico = isSame ? this.servicoOptions[0] : selectedItem;
    },

    async onUpdateCategoria(key, value) {
      const conversationId = this.currentChat.id;
      const updatedAttributes = {
        ...(this.currentChat.custom_attributes || {}),
        [key]: value,
      };
      try {
        await this.$store.dispatch('updateCustomAttributes', {
          conversationId,
          customAttributes: updatedAttributes,
        });
        useAlert(this.$t('CUSTOM_ATTRIBUTES.FORM.UPDATE.SUCCESS'));
      } catch (error) {
        useAlert(this.$t('CUSTOM_ATTRIBUTES.FORM.UPDATE.ERROR'));
      }
    },
  },
};
</script>

<template>
  <div>
    <div v-if="ticketPaiId || ticketFilhosIds.length">
      <ContactDetailsItem
        compact
        :title="$t('CONVERSATION_SIDEBAR.LINKED_TICKETS.SECTION_TITLE')"
      />
      <div class="flex flex-col gap-1.5 px-2 pb-2">
        <LinkedTicketCard
          v-if="ticketPaiId"
          :conversation-id="ticketPaiId"
          :relation-label="
            $t('CONVERSATION_SIDEBAR.LINKED_TICKETS.PARENT_LABEL')
          "
        />
        <LinkedTicketCard
          v-for="childId in ticketFilhosIds"
          :key="childId"
          :conversation-id="childId"
          :relation-label="
            $t('CONVERSATION_SIDEBAR.LINKED_TICKETS.CHILD_LABEL')
          "
        />
      </div>
    </div>
    <div>
      <ContactDetailsItem
        compact
        :title="$t('CONVERSATION_SIDEBAR.SERVICO_LABEL')"
      />
      <MultiselectDropdown
        :options="servicoOptions"
        :selected-item="assignedServico"
        :multiselector-title="$t('CONVERSATION_SIDEBAR.SERVICO_LABEL')"
        :multiselector-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')"
        :no-search-result="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')
        "
        :input-placeholder="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')
        "
        @select="onClickAssignServico"
      />
    </div>
    <div v-if="categoriaDefinition">
      <CustomAttribute
        attribute-key="categoria"
        :attribute-type="categoriaDefinition.attribute_display_type"
        :label="categoriaDefinition.attribute_display_name"
        :description="categoriaDefinition.attribute_description"
        :attribute-regex="categoriaDefinition.regex_pattern"
        :regex-cue="categoriaDefinition.regex_cue"
        :value="categoriaValue"
        @update="onUpdateCategoria"
      />
    </div>
    <div>
      <ContactDetailsItem
        compact
        :title="$t('CONVERSATION_SIDEBAR.ASSIGNEE_LABEL')"
      >
        <template #button>
          <NextButton
            v-if="showSelfAssign"
            link
            xs
            icon="i-lucide-arrow-right"
            class="!gap-1"
            :label="$t('CONVERSATION_SIDEBAR.SELF_ASSIGN')"
            @click="onSelfAssign"
          />
        </template>
      </ContactDetailsItem>
      <MultiselectDropdown
        :options="agentsList"
        :selected-item="assignedAgent"
        :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.AGENT')"
        :multiselector-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')"
        :no-search-result="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')
        "
        :input-placeholder="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')
        "
        @select="onClickAssignAgent"
      />
    </div>
    <div>
      <ContactDetailsItem
        compact
        :title="$t('CONVERSATION_SIDEBAR.TEAM_LABEL')"
      />
      <MultiselectDropdown
        :options="teamsList"
        :selected-item="assignedTeam"
        show-emoji-icon
        :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.TEAM')"
        :multiselector-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')"
        :no-search-result="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.TEAM')
        "
        :input-placeholder="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.TEAM')
        "
        @select="onClickAssignTeam"
      />
    </div>
    <div>
      <ContactDetailsItem compact :title="$t('CONVERSATION.PRIORITY.TITLE')" />
      <MultiselectDropdown
        :options="priorityOptions"
        :selected-item="assignedPriority"
        :multiselector-title="$t('CONVERSATION.PRIORITY.TITLE')"
        :multiselector-placeholder="
          $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SELECT_PLACEHOLDER')
        "
        :no-search-result="
          $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.NO_RESULTS')
        "
        :input-placeholder="
          $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.INPUT_PLACEHOLDER')
        "
        @select="onClickAssignPriority"
      />
    </div>
    <ContactDetailsItem
      compact
      :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_LABELS')"
    />
    <ConversationLabels :conversation-id="conversationId" />

    <div
      v-if="hasPortalInfo"
      class="mt-1 border-t-2 border-n-blue-6 bg-n-blue-1 dark:bg-n-solid-2"
    >
      <p
        class="px-2 pt-2 text-[11px] font-semibold uppercase tracking-wide text-n-blue-11"
      >
        {{ $t('CONVERSATION_SIDEBAR.ACCORDION.PORTAL_INFO') }}
      </p>
      <CustomAttributes
        attribute-type="conversation_attribute"
        attribute-from="conversation_portal_info_panel"
        :include-keys="portalInfoAttributeKeys"
      />
    </div>
  </div>
</template>
