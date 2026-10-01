<!-- eslint-disable vue/v-slot-style -->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useAgentsList } from 'dashboard/composables/useAgentsList';
import { useMacroExecution } from 'dashboard/composables/useMacroExecution';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import ConversationLabels from './labels/LabelBox.vue';
import CustomAttributes from './customAttributes/CustomAttributes.vue';
import LinkedTicketCard from './LinkedTicketCard.vue';
import TicketCustomFields from './TicketCustomFields.vue';
import { FIELD_GROUPS } from 'dashboard/helper/ticketFieldGroups';
import {
  FIELD_LABEL_CLASS,
  FIELD_SIZE,
} from 'dashboard/constants/ticketFieldLayout';
import {
  PORTAL_INFO_ATTRIBUTE_KEYS,
  SERVICO_ATTRIBUTE_KEY,
  TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY,
} from 'dashboard/constants/ticketDetailAttributes';
import {
  useTicketCatalog,
  conversationTicketScope,
} from 'dashboard/composables/useTicketCatalog';
import {
  activeInScope,
  allowedCategories,
  filterPriorityOptions,
} from 'dashboard/helper/ticketCatalogRules';
import { useSaveConversationAttributes } from 'dashboard/composables/useSaveConversationAttributes';
import { CONVERSATION_PRIORITY } from '../../../../shared/constants/messages';
import { CONVERSATION_EVENTS } from '../../../helper/AnalyticsHelper/events';
import { useTrack } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';

// Opção "Nenhum/Nenhuma" de cada lista: no ComboBox vira o campo vazio.
const isNoneOption = item => [null, '', 0].includes(item?.id);
// Agente e bot podem ter o mesmo id.
const optionKey = item =>
  item.assignee_type === 'AgentBot' ? `bot-${item.id}` : String(item.id);

export default {
  components: {
    ComboBox,
    ConversationLabels,
    CustomAttributes,
    LinkedTicketCard,
    NextButton,
    TicketCustomFields,
  },
  props: {
    conversationId: {
      type: [Number, String],
      required: true,
    },
  },
  setup() {
    const { agentsList } = useAgentsList(true, { includeAgentBots: true });
    const { execute: executeMacro, dismissPendingAttributes } =
      useMacroExecution();
    const { state: catalog, fetchList } = useTicketCatalog();
    const saveConversationAttributes = useSaveConversationAttributes();
    return {
      FIELD_GROUPS,
      FIELD_LABEL_CLASS,
      FIELD_SIZE,
      saveConversationAttributes,
      agentsList,
      executeMacro,
      dismissPendingAttributes,
      catalog,
      fetchList,
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
      getInbox: 'inboxes/getInbox',
    }),
    // PATCH LOCAL (fork) - Serviço e Tipo de solicitação vêm dos
    // cadastros de atendimento (Configurações), filtrados pelo tipo de ticket
    // da conversa. A conversa continua guardando os valores por nome em
    // custom_attributes (servico = full_name do serviço).
    customAttributes() {
      return this.currentChat.custom_attributes || {};
    },
    ticketScope() {
      return conversationTicketScope(this.getInbox(this.currentChat.inbox_id));
    },
    noneOption() {
      return { id: '', name: this.$t('CONVERSATION.PRIORITY.OPTIONS.NONE') };
    },
    selectedService() {
      const current = this.customAttributes[SERVICO_ATTRIBUTE_KEY];
      return this.catalog.services.find(item => item.full_name === current);
    },
    selectedCategory() {
      const current = this.customAttributes[TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY];
      return this.catalog.categories.find(item => item.name === current);
    },
    servicoOptions() {
      return this.catalogOptions(
        activeInScope(this.catalog.services, this.ticketScope).map(
          item => item.full_name
        )
      );
    },
    tipoDeSolicitacaoOptions() {
      return this.catalogOptions(
        allowedCategories(
          this.catalog.categories,
          this.selectedService,
          this.ticketScope
        ).map(item => item.name)
      );
    },
    assignedTipoDeSolicitacao() {
      return this.selectedCatalogOption(
        this.tipoDeSolicitacaoOptions,
        TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY
      );
    },
    // Tipo de solicitação com prioridades permitidas limita o seletor de prioridade.
    availablePriorityOptions() {
      return filterPriorityOptions(this.priorityOptions, this.selectedCategory);
    },
    empresaDefinition() {
      return this.getAttributesByModel('conversation_attribute').find(
        attr => attr.attribute_key === 'empresa'
      );
    },
    empresaOptions() {
      return (this.empresaDefinition?.attribute_values || []).map(value => ({
        value,
        label: value,
      }));
    },
    empresaValue() {
      return (this.currentChat.custom_attributes || {}).empresa || '';
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
    assignedServico() {
      return this.selectedCatalogOption(
        this.servicoOptions,
        SERVICO_ATTRIBUTE_KEY
      );
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
  mounted() {
    ['services', 'categories'].forEach(kind => this.fetchList(kind));
  },
  methods: {
    // PATCH LOCAL (fork) - ponte entre as listas {id, name} e o ComboBox
    // {value, label}. Escolher de novo o valor atual limpa o campo: o
    // ComboBox manda '' e o handler recebe o item atual, que já trata "mesmo
    // item" como desmarcar.
    comboOptions(items) {
      return items
        .filter(item => !isNoneOption(item))
        .map(item => ({ value: optionKey(item), label: item.name }));
    },
    comboValue(selected) {
      return selected && !isNoneOption(selected) ? optionKey(selected) : '';
    },
    onComboSelect(items, selected, handler, value) {
      if (value === '') {
        if (this.comboValue(selected)) handler(selected);
        return;
      }
      handler(items.find(item => optionKey(item) === value));
    },
    // PATCH LOCAL (fork) - opções dos seletores dos cadastros ("Nenhuma" +
    // nomes). Valor gravado que não está mais na lista (inativado, ou veio do
    // Portal) continua aparecendo como selecionado em vez de sumir.
    catalogOptions(names) {
      return [this.noneOption, ...names.map(name => ({ id: name, name }))];
    },
    selectedCatalogOption(options, key) {
      const current = this.customAttributes[key];
      if (!current) return this.noneOption;
      return (
        options.find(opt => opt.id === current) || {
          id: current,
          name: current,
        }
      );
    },
    saveCatalogAttributes(changes) {
      return this.saveConversationAttributes(this.currentChat, changes);
    },
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

    // PATCH LOCAL (fork) - serviço com macro (Movidesk): escolher o serviço na
    // conversa aplica a macro ligada a ele (service.macro_id). Se ela resolve
    // a conversa e falta atributo obrigatório, roda sem resolver.
    async runServicoMacro(service, conversationId) {
      if (!this.$store.getters['macros/getMacros'].length) {
        await this.$store.dispatch('macros/get');
      }
      const macro = this.$store.getters['macros/getMacros'].find(
        item => item.id === service.macro_id
      );
      if (!macro) return;

      const pending = this.executeMacro(macro, conversationId, {
        silent: true,
      });
      if (pending) this.dismissPendingAttributes();
      useAlert(
        this.$t('MACROS.EXECUTE.APPLIED_BY_SERVICE', { name: macro.name })
      );
    },

    // PATCH LOCAL (fork) - escolher o serviço grava o tipo de solicitação padrão dele
    // (ou limpa a atual se o novo serviço não a permite), aplica a
    // prioridade padrão e roda a macro ligada.
    async onClickAssignServico(selectedItem) {
      const isSame = this.assignedServico.id === selectedItem.id;
      const servico = isSame ? '' : selectedItem.id;
      const service = this.catalog.services.find(
        item => item.full_name === servico
      );
      const defaultCategory =
        service?.default_category_id &&
        this.catalog.categories.find(
          item => item.id === service.default_category_id
        );
      const currentTipo =
        this.customAttributes[TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY];
      const allowedNames = allowedCategories(
        this.catalog.categories,
        service,
        this.ticketScope
      ).map(item => item.name);
      let categoria = currentTipo;
      if (defaultCategory) categoria = defaultCategory.name;
      else if (!allowedNames.includes(currentTipo)) categoria = '';

      const conversationId = this.currentChat.id;
      const saved = await this.saveCatalogAttributes({
        [SERVICO_ATTRIBUTE_KEY]: servico,
        [TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY]: categoria,
      });
      if (!saved || !service) return;

      const defaultPriority =
        service.default_priority &&
        this.priorityOptions.find(opt => opt.id === service.default_priority);
      if (defaultPriority) this.assignedPriority = defaultPriority;
      if (service.macro_id) this.runServicoMacro(service, conversationId);
    },

    onClickAssignTipoDeSolicitacao(selectedItem) {
      const isSame = this.assignedTipoDeSolicitacao.id === selectedItem.id;
      this.saveCatalogAttributes({
        [TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY]: isSame ? '' : selectedItem.id,
      });
    },

    // Handler genérico reaproveitado por Tipo de solicitação e Empresa -
    // seguem o mesmo formato de update de custom attribute de conversa.
    async onUpdatePortalAttribute(key, value) {
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
  <!-- PATCH LOCAL (fork) - mesmo visual dos campos adicionais (Ações do QA/DEV):
  rótulo pequeno, ComboBox e espaço entre os campos. -->
  <div class="flex flex-col gap-4">
    <div v-if="empresaDefinition" class="flex flex-col gap-1.5">
      <span :class="FIELD_LABEL_CLASS">
        {{ empresaDefinition.attribute_display_name }}
      </span>
      <ComboBox
        :size="FIELD_SIZE"
        :model-value="empresaValue"
        :options="empresaOptions"
        :display-label="empresaValue"
        :placeholder="
          $t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.SELECT_PLACEHOLDER')
        "
        @update:model-value="value => onUpdatePortalAttribute('empresa', value)"
      />
    </div>
    <div class="flex flex-col gap-1.5">
      <span :class="FIELD_LABEL_CLASS">{{
        $t('CONVERSATION_SIDEBAR.TIPO_DE_SOLICITACAO_LABEL')
      }}</span>
      <ComboBox
        :size="FIELD_SIZE"
        :model-value="comboValue(assignedTipoDeSolicitacao)"
        :options="comboOptions(tipoDeSolicitacaoOptions)"
        :display-label="
          comboValue(assignedTipoDeSolicitacao)
            ? assignedTipoDeSolicitacao.name
            : ''
        "
        :placeholder="
          $t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.SELECT_PLACEHOLDER')
        "
        @update:model-value="
          value =>
            onComboSelect(
              tipoDeSolicitacaoOptions,
              assignedTipoDeSolicitacao,
              onClickAssignTipoDeSolicitacao,
              value
            )
        "
      />
    </div>
    <div class="flex flex-col gap-1.5">
      <span :class="FIELD_LABEL_CLASS">{{
        $t('CONVERSATION_SIDEBAR.SERVICO_LABEL')
      }}</span>
      <ComboBox
        :size="FIELD_SIZE"
        :model-value="comboValue(assignedServico)"
        :options="comboOptions(servicoOptions)"
        :display-label="comboValue(assignedServico) ? assignedServico.name : ''"
        :placeholder="
          $t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.SELECT_PLACEHOLDER')
        "
        @update:model-value="
          value =>
            onComboSelect(
              servicoOptions,
              assignedServico,
              onClickAssignServico,
              value
            )
        "
      />
    </div>
    <!-- PATCH LOCAL (fork) - Classificação/Tipo do serviço (campos adicionais) logo depois de Serviço -->
    <TicketCustomFields inline :group="FIELD_GROUPS.CLASSIFICATION" />
    <div class="flex flex-col gap-1.5">
      <span :class="FIELD_LABEL_CLASS">{{
        $t('CONVERSATION.PRIORITY.TITLE')
      }}</span>
      <ComboBox
        :size="FIELD_SIZE"
        :model-value="comboValue(assignedPriority)"
        :options="comboOptions(availablePriorityOptions)"
        :display-label="
          comboValue(assignedPriority) ? assignedPriority.name : ''
        "
        :placeholder="
          $t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.SELECT_PLACEHOLDER')
        "
        @update:model-value="
          value =>
            onComboSelect(
              availablePriorityOptions,
              assignedPriority,
              onClickAssignPriority,
              value
            )
        "
      />
    </div>
    <div class="flex flex-col gap-1.5">
      <div class="flex items-center justify-between gap-2">
        <span :class="FIELD_LABEL_CLASS">
          {{ $t('CONVERSATION_SIDEBAR.ASSIGNEE_LABEL') }}
        </span>
        <NextButton
          v-if="showSelfAssign"
          link
          xs
          icon="i-lucide-arrow-right"
          class="!gap-1"
          :label="$t('CONVERSATION_SIDEBAR.SELF_ASSIGN')"
          @click="onSelfAssign"
        />
      </div>
      <ComboBox
        :size="FIELD_SIZE"
        :model-value="comboValue(assignedAgent)"
        :options="comboOptions(agentsList)"
        :display-label="comboValue(assignedAgent) ? assignedAgent.name : ''"
        :placeholder="
          $t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.SELECT_PLACEHOLDER')
        "
        @update:model-value="
          value =>
            onComboSelect(agentsList, assignedAgent, onClickAssignAgent, value)
        "
      />
    </div>
    <div class="flex flex-col gap-1.5">
      <span :class="FIELD_LABEL_CLASS">{{
        $t('CONVERSATION_SIDEBAR.TEAM_LABEL')
      }}</span>
      <ComboBox
        :size="FIELD_SIZE"
        :model-value="comboValue(assignedTeam)"
        :options="comboOptions(teamsList)"
        :display-label="comboValue(assignedTeam) ? assignedTeam.name : ''"
        :placeholder="
          $t('TICKET_CATALOG.CUSTOM_FIELDS.CONVERSATION.SELECT_PLACEHOLDER')
        "
        @update:model-value="
          value =>
            onComboSelect(teamsList, assignedTeam, onClickAssignTeam, value)
        "
      />
    </div>
    <div
      v-if="ticketPaiId || ticketFilhosIds.length"
      class="flex flex-col gap-1.5"
    >
      <span :class="FIELD_LABEL_CLASS">
        {{ $t('CONVERSATION_SIDEBAR.LINKED_TICKETS.SECTION_TITLE') }}
      </span>
      <div class="flex flex-col gap-1.5">
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
    <div class="flex flex-col gap-1.5">
      <span :class="FIELD_LABEL_CLASS">
        {{ $t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_LABELS') }}
      </span>
      <ConversationLabels :conversation-id="conversationId" />
    </div>

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
