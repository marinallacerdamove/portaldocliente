<script setup>
import { ref, reactive, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { debounce } from '@chatwoot/utils';
import { createContactSearcher } from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper';
import { CONVERSATION_PRIORITY } from 'shared/constants/messages';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';

const NONE_OPTION = { id: '', name: 'Nenhum' };

const dialogRef = ref(null);
const store = useStore();
const searchContacts = createContactSearcher();

const agentsList = useMapGetter('agents/getAgents');
const teams = useMapGetter('teams/getTeams');
const inboxes = useMapGetter('inboxes/getInboxes');
const getAttributesByModel = useMapGetter('attributes/getAttributesByModel');

const targetInbox = computed(
  () =>
    inboxes.value.find(inbox => inbox.name === 'Parceiros') || inboxes.value[0]
);

const attrOptions = key => {
  const def = getAttributesByModel.value('conversation_attribute').find(
    attr => attr.attribute_key === key
  );
  const values = def ? def.attribute_values : [];
  return [NONE_OPTION, ...(values || []).map(value => ({ id: value, name: value }))];
};

const servicoOptions = computed(() => attrOptions('servico'));
const liberacoesOptions = computed(() => attrOptions('liberacoes'));
const decisaoPoOptions = computed(() => attrOptions('decisao_po'));
const statusCobrancaOptions = computed(() => attrOptions('status_cobranca'));

const urgenciaOptions = [
  { id: '', name: 'Nenhuma' },
  { id: CONVERSATION_PRIORITY.URGENT, name: 'Urgente' },
  { id: CONVERSATION_PRIORITY.HIGH, name: 'Alta' },
  { id: CONVERSATION_PRIORITY.MEDIUM, name: 'Média' },
  { id: CONVERSATION_PRIORITY.LOW, name: 'Baixa' },
];

const query = ref('');
const results = ref([]);
const isSearching = ref(false);
const isSubmitting = ref(false);

const emptyForm = () => ({
  contact: null,
  servico: NONE_OPTION,
  categoria: '',
  urgencia: urgenciaOptions[0],
  prazoResolucao: '',
  agent: null,
  team: null,
  liberacoes: NONE_OPTION,
  issueJira: '',
  decisaoPo: NONE_OPTION,
  statusCobranca: NONE_OPTION,
  dataEntrega: '',
  dataAtualizacaoSistema: '',
  ccAgentIds: [],
  subject: '',
  message: '',
});

const formState = reactive(emptyForm());

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('attributes/get');
});

const onSearch = debounce(async () => {
  isSearching.value = true;
  try {
    results.value = await searchContacts(query.value, { skipMinLength: true });
  } finally {
    isSearching.value = false;
  }
}, 400);

const selectContact = contact => {
  formState.contact = contact;
  results.value = [];
  query.value = contact.name;
};

const onSelectAgent = agent => {
  formState.agent = agent;
  const agentTeamIds = agent?.team_ids || [];
  const matchingTeam = teams.value.find(team => agentTeamIds.includes(team.id));
  if (matchingTeam) formState.team = matchingTeam;
};

const toggleCcAgent = agentId => {
  const idx = formState.ccAgentIds.indexOf(agentId);
  if (idx === -1) {
    formState.ccAgentIds.push(agentId);
  } else {
    formState.ccAgentIds.splice(idx, 1);
  }
};

const canSubmit = computed(
  () =>
    !!formState.contact &&
    !!formState.team &&
    !!formState.message.trim() &&
    !!targetInbox.value
);

const reset = () => {
  Object.assign(formState, emptyForm());
  query.value = '';
  results.value = [];
};

const open = () => {
  reset();
  dialogRef.value?.open();
};

const close = () => {
  dialogRef.value?.close();
};

const onSubmit = async () => {
  if (!canSubmit.value) return;
  isSubmitting.value = true;

  const contentLines = [];
  if (formState.subject.trim()) contentLines.push(formState.subject.trim());
  contentLines.push(formState.message.trim());

  try {
    const data = await store.dispatch('contactConversations/create', {
      params: {
        inboxId: targetInbox.value.id,
        contactId: formState.contact.id,
        message: { content: contentLines.join('\n\n') },
      },
    });

    await store.dispatch('assignTeam', {
      conversationId: data.id,
      teamId: formState.team.id,
    });

    if (formState.agent) {
      await store.dispatch('assignAgent', {
        conversationId: data.id,
        agentId: formState.agent.id,
      });
    }

    if (formState.urgencia?.id) {
      await store.dispatch('assignPriority', {
        conversationId: data.id,
        priority: formState.urgencia.id,
      });
    }

    const customAttributes = {};
    if (formState.servico?.id) customAttributes.servico = formState.servico.id;
    if (formState.categoria.trim()) customAttributes.categoria = formState.categoria.trim();
    if (formState.prazoResolucao) customAttributes.prazo_resolucao = formState.prazoResolucao;
    if (formState.liberacoes?.id) customAttributes.liberacoes = formState.liberacoes.id;
    if (formState.issueJira.trim()) customAttributes.issue_jira = formState.issueJira.trim();
    if (formState.decisaoPo?.id) customAttributes.decisao_po = formState.decisaoPo.id;
    if (formState.statusCobranca?.id) customAttributes.status_cobranca = formState.statusCobranca.id;
    if (formState.dataEntrega) customAttributes.data_entrega = formState.dataEntrega;
    if (formState.dataAtualizacaoSistema) {
      customAttributes.data_atualizacao_sistema = formState.dataAtualizacaoSistema;
    }
    if (Object.keys(customAttributes).length) {
      await store.dispatch('updateCustomAttributes', {
        conversationId: data.id,
        customAttributes,
      });
    }

    if (formState.ccAgentIds.length) {
      await store.dispatch('conversationWatchers/update', {
        conversationId: data.id,
        userIds: formState.ccAgentIds,
      });
    }

    useAlert('Ticket interno criado!', {
      type: 'link',
      to: `/app/accounts/${data.account_id}/conversations/${data.id}`,
      message: 'Ver ticket',
    });
    close();
  } catch (error) {
    useAlert('Erro ao criar o ticket interno.');
  } finally {
    isSubmitting.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <slot name="trigger" :open="open" />
  <Dialog
    ref="dialogRef"
    title="Novo ticket interno"
    width="3xl"
    overflow-y-auto
    confirm-button-label="Salvar"
    :is-loading="isSubmitting"
    :disable-confirm-button="!canSubmit"
    @confirm="onSubmit"
  >
    <div class="grid grid-cols-2 gap-6 w-full max-h-[70vh] overflow-y-auto pr-1">
      <div class="flex flex-col gap-3">
        <div class="relative">
          <p class="text-xs text-n-slate-11 mb-1">Solicitante</p>
          <input
            v-model="query"
            type="text"
            placeholder="Buscar contato..."
            class="w-full h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
            @input="onSearch"
          />
          <ul
            v-if="results.length"
            class="absolute z-10 w-full mt-1 bg-n-solid-2 border border-n-weak rounded-md max-h-40 overflow-y-auto"
          >
            <li
              v-for="contact in results"
              :key="contact.id"
              class="px-2 py-1 text-sm cursor-pointer hover:bg-n-alpha-2"
              @click="selectContact(contact)"
            >
              {{ contact.name }}
              <span class="text-n-slate-10">{{ contact.email }}</span>
            </li>
          </ul>
          <p v-if="formState.contact" class="text-xs text-n-teal-11 mt-1">
            Selecionado: {{ formState.contact.name }}
          </p>
        </div>

        <div>
          <p class="text-xs text-n-slate-11 mb-1">Serviço</p>
          <MultiselectDropdown
            :options="servicoOptions"
            :selected-item="formState.servico"
            multiselector-title="Serviço"
            multiselector-placeholder="Selecione"
            no-search-result="Nenhuma opção encontrada"
            input-placeholder="Buscar"
            @select="formState.servico = $event"
          />
        </div>

        <div class="grid grid-cols-2 gap-2">
          <div>
            <p class="text-xs text-n-slate-11 mb-1">Categoria</p>
            <input
              v-model="formState.categoria"
              type="text"
              class="w-full h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
            />
          </div>
          <div>
            <p class="text-xs text-n-slate-11 mb-1">Urgência</p>
            <MultiselectDropdown
              :options="urgenciaOptions"
              :selected-item="formState.urgencia"
              multiselector-title="Urgência"
              multiselector-placeholder="Selecione"
              no-search-result="Nenhuma opção encontrada"
              input-placeholder="Buscar"
              @select="formState.urgencia = $event"
            />
          </div>
        </div>

        <div>
          <p class="text-xs text-n-slate-11 mb-1">Previsão de solução</p>
          <input
            v-model="formState.prazoResolucao"
            type="date"
            class="w-full h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
          />
        </div>

        <div>
          <p class="text-xs text-n-slate-11 mb-1">Responsável (Agente)</p>
          <MultiselectDropdown
            :options="agentsList"
            :selected-item="formState.agent"
            multiselector-title="Agente"
            multiselector-placeholder="Selecione"
            no-search-result="Nenhum agente encontrado"
            input-placeholder="Buscar agente"
            @select="onSelectAgent"
          />
        </div>

        <div>
          <p class="text-xs text-n-slate-11 mb-1">Time</p>
          <MultiselectDropdown
            :options="teams"
            :selected-item="formState.team"
            show-emoji-icon
            multiselector-title="Time"
            multiselector-placeholder="Selecione"
            no-search-result="Nenhum time encontrado"
            input-placeholder="Buscar time"
            @select="formState.team = $event"
          />
        </div>

        <div class="grid grid-cols-2 gap-2">
          <div>
            <p class="text-xs text-n-slate-11 mb-1">Liberações</p>
            <MultiselectDropdown
              :options="liberacoesOptions"
              :selected-item="formState.liberacoes"
              multiselector-title="Liberações"
              multiselector-placeholder="Selecione"
              no-search-result="Nenhuma opção encontrada"
              input-placeholder="Buscar"
              @select="formState.liberacoes = $event"
            />
          </div>
          <div>
            <p class="text-xs text-n-slate-11 mb-1">Issue Jira</p>
            <input
              v-model="formState.issueJira"
              type="text"
              class="w-full h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
            />
          </div>
        </div>

        <div class="grid grid-cols-2 gap-2">
          <div>
            <p class="text-xs text-n-slate-11 mb-1">Decisão PO</p>
            <MultiselectDropdown
              :options="decisaoPoOptions"
              :selected-item="formState.decisaoPo"
              multiselector-title="Decisão PO"
              multiselector-placeholder="Selecione"
              no-search-result="Nenhuma opção encontrada"
              input-placeholder="Buscar"
              @select="formState.decisaoPo = $event"
            />
          </div>
          <div>
            <p class="text-xs text-n-slate-11 mb-1">Status da Cobrança</p>
            <MultiselectDropdown
              :options="statusCobrancaOptions"
              :selected-item="formState.statusCobranca"
              multiselector-title="Status da Cobrança"
              multiselector-placeholder="Selecione"
              no-search-result="Nenhuma opção encontrada"
              input-placeholder="Buscar"
              @select="formState.statusCobranca = $event"
            />
          </div>
        </div>

        <div class="grid grid-cols-2 gap-2">
          <div>
            <p class="text-xs text-n-slate-11 mb-1">Data Entrega</p>
            <input
              v-model="formState.dataEntrega"
              type="date"
              class="w-full h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
            />
          </div>
          <div>
            <p class="text-xs text-n-slate-11 mb-1">Data Atualização Sistema</p>
            <input
              v-model="formState.dataAtualizacaoSistema"
              type="date"
              class="w-full h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
            />
          </div>
        </div>

        <div>
          <p class="text-xs text-n-slate-11 mb-1">
            Cc (agentes adicionados como participantes)
          </p>
          <div
            class="max-h-28 overflow-y-auto border border-n-weak rounded-md p-2 flex flex-col gap-1"
          >
            <label
              v-for="agent in agentsList"
              :key="agent.id"
              class="flex items-center gap-2 text-sm text-n-slate-12 cursor-pointer"
            >
              <input
                type="checkbox"
                :checked="formState.ccAgentIds.includes(agent.id)"
                @change="toggleCcAgent(agent.id)"
              />
              {{ agent.name }}
            </label>
          </div>
        </div>
      </div>

      <div class="flex flex-col gap-3">
        <div>
          <p class="text-xs text-n-slate-11 mb-1">Assunto</p>
          <input
            v-model="formState.subject"
            type="text"
            class="w-full h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
          />
        </div>
        <div class="flex-1 flex flex-col">
          <p class="text-xs text-n-slate-11 mb-1">Mensagem</p>
          <textarea
            v-model="formState.message"
            rows="18"
            placeholder="Digite algo..."
            class="w-full flex-1 p-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
          />
        </div>
      </div>
    </div>
  </Dialog>
</template>
