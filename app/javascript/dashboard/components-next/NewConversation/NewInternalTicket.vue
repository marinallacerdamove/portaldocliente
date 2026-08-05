<script setup>
import { ref, reactive, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import FileUpload from 'vue-upload-component';
import { useFileUpload } from 'dashboard/composables/useFileUpload';
import {
  createContactSearcher,
  prepareAttachmentPayload,
} from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper';
import {
  CONVERSATION_PRIORITY,
  ALLOWED_FILE_TYPES,
} from 'shared/constants/messages';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import AttachmentPreviews from 'dashboard/components-next/NewConversation/components/AttachmentPreviews.vue';

const { t } = useI18n();
const NONE_OPTION = computed(() => ({
  id: '',
  name: t('NEW_INTERNAL_TICKET_DIALOG.NONE_OPTION'),
}));

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
  const def = getAttributesByModel
    .value('conversation_attribute')
    .find(attr => attr.attribute_key === key);
  const values = def ? def.attribute_values : [];
  return [
    NONE_OPTION.value,
    ...(values || []).map(value => ({ id: value, name: value })),
  ];
};

const servicoOptions = computed(() => attrOptions('servico'));
const liberacoesOptions = computed(() => attrOptions('liberacoes'));
const decisaoPoOptions = computed(() => attrOptions('decisao_po'));
const statusCobrancaOptions = computed(() => attrOptions('status_cobranca'));

const urgenciaOptions = computed(() => [
  { id: '', name: t('NEW_INTERNAL_TICKET_DIALOG.URGENCIA_OPTIONS.NONE') },
  {
    id: CONVERSATION_PRIORITY.URGENT,
    name: t('NEW_INTERNAL_TICKET_DIALOG.URGENCIA_OPTIONS.URGENT'),
  },
  {
    id: CONVERSATION_PRIORITY.HIGH,
    name: t('NEW_INTERNAL_TICKET_DIALOG.URGENCIA_OPTIONS.HIGH'),
  },
  {
    id: CONVERSATION_PRIORITY.MEDIUM,
    name: t('NEW_INTERNAL_TICKET_DIALOG.URGENCIA_OPTIONS.MEDIUM'),
  },
  {
    id: CONVERSATION_PRIORITY.LOW,
    name: t('NEW_INTERNAL_TICKET_DIALOG.URGENCIA_OPTIONS.LOW'),
  },
]);

const query = ref('');
const results = ref([]);
const isSearching = ref(false);
const isSubmitting = ref(false);
const attachedFiles = ref([]);

const { onFileUpload } = useFileUpload({
  attachFile: ({ blob, file }) => {
    if (!file) return;
    const reader = new FileReader();
    reader.readAsDataURL(file.file);
    reader.onloadend = () => {
      attachedFiles.value = [
        ...attachedFiles.value,
        {
          resource: blob || file,
          isPrivate: false,
          thumb: reader.result,
          blobSignedId: blob?.signed_id,
        },
      ];
    };
  },
});

const emptyForm = () => ({
  contact: null,
  servico: NONE_OPTION.value,
  categoria: '',
  urgencia: urgenciaOptions.value[0],
  prazoResolucao: '',
  agent: null,
  team: null,
  liberacoes: NONE_OPTION.value,
  issueJira: '',
  decisaoPo: NONE_OPTION.value,
  statusCobranca: NONE_OPTION.value,
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
  attachedFiles.value = [];
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
        files: prepareAttachmentPayload(attachedFiles.value, false),
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
    if (formState.categoria.trim())
      customAttributes.categoria = formState.categoria.trim();
    if (formState.prazoResolucao)
      customAttributes.prazo_resolucao = formState.prazoResolucao;
    if (formState.liberacoes?.id)
      customAttributes.liberacoes = formState.liberacoes.id;
    if (formState.issueJira.trim())
      customAttributes.issue_jira = formState.issueJira.trim();
    if (formState.decisaoPo?.id)
      customAttributes.decisao_po = formState.decisaoPo.id;
    if (formState.statusCobranca?.id)
      customAttributes.status_cobranca = formState.statusCobranca.id;
    if (formState.dataEntrega)
      customAttributes.data_entrega = formState.dataEntrega;
    if (formState.dataAtualizacaoSistema) {
      customAttributes.data_atualizacao_sistema =
        formState.dataAtualizacaoSistema;
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

    useAlert(t('NEW_INTERNAL_TICKET_DIALOG.CREATE_SUCCESS'), {
      type: 'link',
      to: `/app/accounts/${data.account_id}/conversations/${data.id}`,
      message: t('NEW_INTERNAL_TICKET_DIALOG.VIEW_TICKET'),
    });
    close();
  } catch (error) {
    useAlert(t('NEW_INTERNAL_TICKET_DIALOG.CREATE_ERROR'));
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
    :title="t('NEW_INTERNAL_TICKET_DIALOG.TITLE')"
    width="full"
    overflow-y-auto
    :is-loading="isSubmitting"
    :disable-confirm-button="!canSubmit"
    @confirm="onSubmit"
  >
    <div
      class="grid grid-cols-[26rem_1fr] items-start gap-6 w-full max-h-[80vh] overflow-y-auto pr-1"
    >
      <div class="flex flex-col gap-3">
        <div class="relative">
          <p class="text-xs text-n-slate-11 mb-1">
            {{ t('NEW_INTERNAL_TICKET_DIALOG.REQUESTER_LABEL') }}
          </p>
          <input
            v-model="query"
            type="text"
            :placeholder="
              t('NEW_INTERNAL_TICKET_DIALOG.CONTACT_SEARCH_PLACEHOLDER')
            "
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
            {{
              t('NEW_INTERNAL_TICKET_DIALOG.SELECTED_LABEL', {
                name: formState.contact.name,
              })
            }}
          </p>
        </div>

        <div>
          <p class="text-xs text-n-slate-11 mb-1">
            {{ t('CONVERSATION_SIDEBAR.SERVICO_LABEL') }}
          </p>
          <MultiselectDropdown
            :options="servicoOptions"
            :selected-item="formState.servico"
            :multiselector-title="t('CONVERSATION_SIDEBAR.SERVICO_LABEL')"
            :multiselector-placeholder="
              t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')
            "
            :no-search-result="t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')"
            :input-placeholder="
              t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
            "
            @select="formState.servico = $event"
          />
        </div>

        <div class="grid grid-cols-2 gap-2">
          <div>
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('NEW_INTERNAL_TICKET_DIALOG.CATEGORIA_LABEL') }}
            </p>
            <input
              v-model="formState.categoria"
              type="text"
              class="w-full h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
            />
          </div>
          <div>
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('NEW_INTERNAL_TICKET_DIALOG.URGENCIA_LABEL') }}
            </p>
            <MultiselectDropdown
              :options="urgenciaOptions"
              :selected-item="formState.urgencia"
              :multiselector-title="
                t('NEW_INTERNAL_TICKET_DIALOG.URGENCIA_LABEL')
              "
              :multiselector-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')
              "
              :no-search-result="
                t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')
              "
              :input-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
              "
              @select="formState.urgencia = $event"
            />
          </div>
        </div>

        <div>
          <p class="text-xs text-n-slate-11 mb-1">
            {{ t('NEW_INTERNAL_TICKET_DIALOG.PREVISAO_LABEL') }}
          </p>
          <input
            v-model="formState.prazoResolucao"
            type="date"
            class="w-full h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
          />
        </div>

        <div>
          <p class="text-xs text-n-slate-11 mb-1">
            {{ t('NEW_INTERNAL_TICKET_DIALOG.RESPONSIBLE_LABEL') }}
          </p>
          <MultiselectDropdown
            :options="agentsList"
            :selected-item="formState.agent"
            :multiselector-title="
              t('NEW_INTERNAL_TICKET_DIALOG.RESPONSIBLE_LABEL')
            "
            :multiselector-placeholder="
              t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')
            "
            :no-search-result="t('NEW_INTERNAL_TICKET_DIALOG.NO_AGENT_FOUND')"
            :input-placeholder="
              t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_AGENT_PLACEHOLDER')
            "
            @select="onSelectAgent"
          />
        </div>

        <div>
          <p class="text-xs text-n-slate-11 mb-1">
            {{ t('NEW_INTERNAL_TICKET_DIALOG.TEAM_LABEL') }}
          </p>
          <MultiselectDropdown
            :options="teams"
            :selected-item="formState.team"
            show-emoji-icon
            :multiselector-title="t('NEW_INTERNAL_TICKET_DIALOG.TEAM_LABEL')"
            :multiselector-placeholder="
              t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')
            "
            :no-search-result="t('NEW_INTERNAL_TICKET_DIALOG.NO_TEAM_FOUND')"
            :input-placeholder="
              t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_TEAM_PLACEHOLDER')
            "
            @select="formState.team = $event"
          />
        </div>

        <div class="grid grid-cols-2 gap-2">
          <div>
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('NEW_INTERNAL_TICKET_DIALOG.LIBERACOES_LABEL') }}
            </p>
            <MultiselectDropdown
              :options="liberacoesOptions"
              :selected-item="formState.liberacoes"
              :multiselector-title="
                t('NEW_INTERNAL_TICKET_DIALOG.LIBERACOES_LABEL')
              "
              :multiselector-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')
              "
              :no-search-result="
                t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')
              "
              :input-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
              "
              @select="formState.liberacoes = $event"
            />
          </div>
          <div>
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('NEW_INTERNAL_TICKET_DIALOG.ISSUE_JIRA_LABEL') }}
            </p>
            <input
              v-model="formState.issueJira"
              type="text"
              class="w-full h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
            />
          </div>
        </div>

        <div class="grid grid-cols-2 gap-2">
          <div>
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('NEW_INTERNAL_TICKET_DIALOG.DECISAO_PO_LABEL') }}
            </p>
            <MultiselectDropdown
              :options="decisaoPoOptions"
              :selected-item="formState.decisaoPo"
              :multiselector-title="
                t('NEW_INTERNAL_TICKET_DIALOG.DECISAO_PO_LABEL')
              "
              :multiselector-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')
              "
              :no-search-result="
                t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')
              "
              :input-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
              "
              @select="formState.decisaoPo = $event"
            />
          </div>
          <div>
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('NEW_INTERNAL_TICKET_DIALOG.STATUS_COBRANCA_LABEL') }}
            </p>
            <MultiselectDropdown
              :options="statusCobrancaOptions"
              :selected-item="formState.statusCobranca"
              :multiselector-title="
                t('NEW_INTERNAL_TICKET_DIALOG.STATUS_COBRANCA_LABEL')
              "
              :multiselector-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')
              "
              :no-search-result="
                t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')
              "
              :input-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
              "
              @select="formState.statusCobranca = $event"
            />
          </div>
        </div>

        <div class="grid grid-cols-2 gap-2">
          <div>
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('NEW_INTERNAL_TICKET_DIALOG.DATA_ENTREGA_LABEL') }}
            </p>
            <input
              v-model="formState.dataEntrega"
              type="date"
              class="w-full h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
            />
          </div>
          <div>
            <p class="text-xs text-n-slate-11 mb-1">
              {{ t('NEW_INTERNAL_TICKET_DIALOG.DATA_ATUALIZACAO_LABEL') }}
            </p>
            <input
              v-model="formState.dataAtualizacaoSistema"
              type="date"
              class="w-full h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
            />
          </div>
        </div>

        <div>
          <p class="text-xs text-n-slate-11 mb-1">
            {{ t('NEW_INTERNAL_TICKET_DIALOG.CC_LABEL') }}
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
          <p class="text-xs text-n-slate-11 mb-1">
            {{ t('NEW_INTERNAL_TICKET_DIALOG.SUBJECT_LABEL') }}
          </p>
          <input
            v-model="formState.subject"
            type="text"
            class="w-full h-8 px-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12"
          />
        </div>
        <div class="flex flex-col">
          <p class="text-xs text-n-slate-11 mb-1">
            {{ t('NEW_INTERNAL_TICKET_DIALOG.MESSAGE_LABEL') }}
          </p>
          <textarea
            v-model="formState.message"
            rows="14"
            :placeholder="t('NEW_INTERNAL_TICKET_DIALOG.MESSAGE_PLACEHOLDER')"
            class="w-full min-h-[22rem] p-2 rounded-md outline outline-1 outline-n-weak bg-n-solid-2 text-sm text-n-slate-12 resize-y"
          />
          <AttachmentPreviews
            v-if="attachedFiles.length"
            class="!p-0 !max-h-none mt-2"
            :attachments="attachedFiles"
            @update:attachments="attachedFiles = $event"
          />
          <FileUpload
            input-id="newInternalTicketAttachment"
            :size="4096 * 4096"
            :accept="ALLOWED_FILE_TYPES"
            multiple
            :drop-directory="false"
            :data="{
              direct_upload_url: '/rails/active_storage/direct_uploads',
              direct_upload: true,
            }"
            class="mt-2 self-start"
            @input-file="onFileUpload"
          >
            <Button
              icon="i-lucide-paperclip"
              variant="outline"
              color="slate"
              size="sm"
              :label="t('NEW_INTERNAL_TICKET_DIALOG.ATTACH_BUTTON')"
            />
          </FileUpload>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-end w-full gap-2">
        <Button
          variant="faded"
          color="slate"
          size="sm"
          type="button"
          :label="t('DIALOG.BUTTONS.CANCEL')"
          @click="close"
        />
        <Button
          color="ruby"
          size="sm"
          type="submit"
          :label="t('NEW_INTERNAL_TICKET_DIALOG.SAVE_BUTTON')"
          :is-loading="isSubmitting"
          :disabled="!canSubmit"
        />
      </div>
    </template>
  </Dialog>
</template>
