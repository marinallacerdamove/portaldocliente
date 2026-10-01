<script setup>
import { ref, reactive, computed, onMounted, nextTick } from 'vue';
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
import {
  useTicketCatalog,
  conversationTicketScope,
} from 'dashboard/composables/useTicketCatalog';
import {
  activeInScope,
  allowedCategories,
} from 'dashboard/helper/ticketCatalogRules';
import { conversationOrigin } from 'dashboard/composables/useConversationCustomFields';
import {
  CUSTOM_FIELDS_ATTRIBUTE_KEY,
  visibleCustomFields,
} from 'dashboard/helper/ticketFieldRules';
import {
  FIELD_GROUPS,
  itemsInGroup,
  fieldDisplayName,
} from 'dashboard/helper/ticketFieldGroups';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import {
  FIELD_LABEL_CLASS,
  FIELD_SIZE,
  FIELD_INPUT_CLASS,
} from 'dashboard/constants/ticketFieldLayout';
import Button from 'dashboard/components-next/button/Button.vue';
import AttachmentPreviews from 'dashboard/components-next/NewConversation/components/AttachmentPreviews.vue';

const { t } = useI18n();
const NONE_OPTION = computed(() => ({
  id: '',
  name: t('NEW_INTERNAL_TICKET_DIALOG.NONE_OPTION'),
}));

// Rótulo à esquerda, campo à direita (painel de propriedades).
const FIELD_ROW_CLASS = 'grid grid-cols-[8.5rem_1fr] items-center gap-3';
const SECTION_TITLE_CLASS =
  'flex items-center gap-2 mb-0 text-xs font-semibold uppercase tracking-wide text-n-slate-11';

// Interno (padrão: o cliente não vê nem é notificado) x Visível ao cliente.
const VISIBILITY_OPTIONS = [
  {
    key: 'internal',
    visible: false,
    icon: 'i-lucide-lock',
    label: 'NEW_INTERNAL_TICKET_DIALOG.INTERNAL_TICKET_BADGE',
    activeClass: 'text-n-amber-11',
  },
  {
    key: 'visible',
    visible: true,
    icon: 'i-lucide-eye',
    label: 'NEW_INTERNAL_TICKET_DIALOG.VISIBLE_TO_CLIENT_BADGE',
    activeClass: 'text-n-teal-11',
  },
];

// Listas {id, name} <-> ComboBox {value, label}; a opção "Nenhum" (id vazio)
// fica de fora, o campo vazio já faz esse papel.
const toComboOptions = items =>
  items
    .filter(item => item.id !== '' && item.id != null)
    .map(item => ({ value: item.id, label: item.name }));
const fromCombo = (items, value) =>
  value === '' ? null : items.find(item => item.id === value) || null;

const dialogRef = ref(null);
const store = useStore();
const searchContacts = createContactSearcher();

const agentsList = useMapGetter('agents/getAgents');
const teams = useMapGetter('teams/getTeams');
const inboxes = useMapGetter('inboxes/getInboxes');
const { state: catalog, fetchList } = useTicketCatalog();

// Caixa é escolhida explicitamente no formulário agora (formState.inbox) -
// quem cria vê e decide pra onde o ticket vai (Tickets Internos, Portal do
// Cliente, um canal de WhatsApp etc.), em vez de só existir a opção
// "sempre Tickets Internos" de antes. "Tickets Internos" continua sendo o
// valor padrão ao abrir o formulário (ver emptyForm), preservando o
// comportamento de sempre pra quem não mexer nesse campo.
const defaultInbox = computed(() =>
  inboxes.value.find(inbox => inbox.name === 'Tickets Internos')
);

// PATCH LOCAL (fork) - Liberações, Decisão PO e Status da Cobrança são campos
// adicionais (Configurações > Campos adicionais): opções vêm de lá e o valor
// vai pra custom_attributes.campos_adicionais, igual a lateral da conversa.
const fieldOptions = key => {
  const field = catalog.customFields.find(item => item.key === key);
  return [
    NONE_OPTION.value,
    ...(field?.options || []).map(value => ({ id: value, name: value })),
  ];
};

const liberacoesOptions = computed(() => fieldOptions('liberacoes'));
const decisaoPoOptions = computed(() => fieldOptions('decisao_po'));
const statusCobrancaOptions = computed(() =>
  fieldOptions('status_da_cobranca')
);

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
// Mensagens selecionadas de outra conversa (ver
// MessagesView.vue#handleCreateInternalTicketFromSelection) - cada uma é
// copiada individualmente pelo backend depois que o ticket é criado (ver
// onSubmit), nunca concatenadas num texto só.
const selectedMessages = ref([]);
const sourceConversationId = ref(null);

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
  inbox: defaultInbox.value || null,
  tipo: NONE_OPTION.value,
  servico: NONE_OPTION.value,
  // Classificação/Tipo do serviço (campos adicionais), por chave do campo.
  classification: {},
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
  // Padrão desligado: por ser o fluxo de "ticket interno", a mensagem
  // inicial nasce como nota privada (não notifica/não aparece pro
  // cliente) - quem cria escolhe ligar se quiser que o cliente veja
  // desta vez.
  visibleToClient: false,
});

const formState = reactive(emptyForm());

// PATCH LOCAL (fork) - Serviço vem do cadastro de atendimento: só os ativos
// do tipo de ticket da caixa escolhida (Tickets Internos = 'interno'),
// gravando o full_name em custom_attributes.servico.
const servicoOptions = computed(() => [
  NONE_OPTION.value,
  ...activeInScope(
    catalog.services,
    conversationTicketScope(formState.inbox)
  ).map(service => ({ id: service.full_name, name: service.full_name })),
]);

const selectedService = computed(() =>
  catalog.services.find(service => service.full_name === formState.servico.id)
);

// Tipo de solicitação (= Categoria do Movidesk): limitado pelo serviço, igual
// "Ações da conversa".
const tipoOptions = computed(() => [
  NONE_OPTION.value,
  ...allowedCategories(
    catalog.categories,
    selectedService.value,
    conversationTicketScope(formState.inbox)
  ).map(category => ({ id: category.name, name: category.name })),
]);

// Tipo que o serviço não permite cai pro padrão do serviço (ou Nenhum).
const keepValidTipo = () => {
  if (tipoOptions.value.some(option => option.id === formState.tipo.id)) return;
  const defaultCategory = catalog.categories.find(
    category => category.id === selectedService.value?.default_category_id
  );
  formState.tipo =
    tipoOptions.value.find(option => option.id === defaultCategory?.name) ||
    NONE_OPTION.value;
};

// Trocar a caixa pode mudar o tipo de ticket: serviço que não vale mais sai.
const onSelectInbox = inbox => {
  formState.inbox = inbox;
  const stillValid = servicoOptions.value.some(
    option => option.id === formState.servico.id
  );
  if (!stillValid) formState.servico = NONE_OPTION.value;
  keepValidTipo();
};

const onSelectServico = option => {
  formState.servico = option;
  keepValidTipo();
};

// Classificação/Tipo do serviço: os campos que as regras de exibição abrem pro
// que já foi escolhido no formulário (serviço, tipo, canal, time...).
const classificationItems = computed(() =>
  itemsInGroup(
    visibleCustomFields({
      rules: catalog.fieldRules,
      fields: catalog.customFields,
      context: {
        servico: formState.servico.id,
        tipo_de_solicitacao: formState.tipo.id,
        concluded: false,
        origem: conversationOrigin(formState.inbox),
        empresa: formState.contact?.additionalAttributes?.companyName,
        equipe: formState.team?.name,
        responsavel: formState.agent?.name,
        values: formState.classification,
      },
    }),
    FIELD_GROUPS.CLASSIFICATION
  ).filter(item => item.editable_by_agents)
);

const fieldComboOptions = field =>
  field.options.map(option => ({ value: option, label: option }));

const setClassification = (key, value) => {
  const next = { ...formState.classification };
  if (value) next[key] = value;
  else delete next[key];
  formState.classification = next;
};

const messageEditorRef = ref(null);
const messageHasContent = computed(() => {
  const html = formState.message || '';
  return /<img/i.test(html) || html.replace(/<[^>]*>/g, '').trim().length > 0;
});

const onMessageInput = () => {
  formState.message = messageEditorRef.value?.innerHTML || '';
};

// Preview local (blob:) da imagem colada, inserido no ponto do cursor pra
// dar a mesma sensação do editor do Portal - "a imagem fica no corpo da
// mensagem" enquanto escreve. A URL blob: só existe nesta aba, então essa
// tag <img> é removida do texto no onSubmit (stripPastePreviews); o arquivo
// de verdade sempre viaja como anexo real (onFileUpload abaixo), que é quem
// garante que a imagem apareça de fato pra quem for ver o ticket depois.
const pasteAttachmentId = ref(0);
const pastedImagePreviews = [];
const PASTE_PREVIEW_ATTR = 'data-paste-preview-key';

function insertImageAtCursor(url, key) {
  const editor = messageEditorRef.value;
  if (!editor) return;
  editor.focus();

  const img = document.createElement('img');
  img.src = url;
  img.setAttribute(PASTE_PREVIEW_ATTR, key);
  img.className = 'max-w-full max-h-64 rounded-md my-1 align-middle';

  const selection = window.getSelection();
  const range =
    selection?.rangeCount > 0 && editor.contains(selection.anchorNode)
      ? selection.getRangeAt(0)
      : (() => {
          const r = document.createRange();
          r.selectNodeContents(editor);
          r.collapse(false);
          return r;
        })();

  range.deleteContents();
  range.insertNode(img);
  range.setStartAfter(img);
  range.setEndAfter(img);
  selection.removeAllRanges();
  selection.addRange(range);
}

const onPasteMessage = e => {
  const files = e.clipboardData?.files;
  if (!files?.length) return;

  const validFiles = Array.from(files).filter(file => file.size > 0);
  if (!validFiles.length) return;

  e.preventDefault();

  validFiles.forEach(file => {
    pasteAttachmentId.value += 1;
    const id = `paste-attachment-${pasteAttachmentId.value}`;

    if (file.type.startsWith('image/')) {
      const previewUrl = URL.createObjectURL(file);
      pastedImagePreviews.push({ key: id, url: previewUrl });
      insertImageAtCursor(previewUrl, id);
      onMessageInput();
    }

    onFileUpload({
      file,
      name: file.name,
      type: file.type,
      size: file.size,
      id,
    });
  });
};

const stripPastePreviews = html =>
  html.replace(
    new RegExp(`<img[^>]*${PASTE_PREVIEW_ATTR}="[^"]*"[^>]*>`, 'g'),
    ''
  );

onMounted(() => {
  store.dispatch('agents/get');
  ['services', 'categories', 'customFields', 'fieldRules'].forEach(kind =>
    fetchList(kind)
  );
});

const onSearch = debounce(async () => {
  isSearching.value = true;
  try {
    results.value = await searchContacts(query.value, { skipMinLength: true });
  } finally {
    isSearching.value = false;
  }
}, 400);

const selectedContactLabel = computed(() => {
  if (!formState.contact) return '';
  const company = formState.contact.additionalAttributes?.companyName;
  const key = company
    ? 'NEW_INTERNAL_TICKET_DIALOG.SELECTED_LABEL_WITH_COMPANY'
    : 'NEW_INTERNAL_TICKET_DIALOG.SELECTED_LABEL';
  return t(key, { name: formState.contact.name, company });
});

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
    !!formState.inbox &&
    !!formState.team &&
    (messageHasContent.value ||
      attachedFiles.value.length > 0 ||
      selectedMessages.value.length > 0)
);

const reset = () => {
  pastedImagePreviews.forEach(preview => URL.revokeObjectURL(preview.url));
  pastedImagePreviews.length = 0;
  Object.assign(formState, emptyForm());
  query.value = '';
  results.value = [];
  attachedFiles.value = [];
  selectedMessages.value = [];
  sourceConversationId.value = null;
};

// prefill vem de fora (ex.: seleção de mensagens no Message.vue) já resolvido
// - contato no mesmo formato camelCase que selectContact() espera. Quando
// vem de uma seleção de mensagens (prefill.selectedMessages), o editor de
// mensagem fica vazio de propósito - essas mensagens não vão pro texto
// livre, são copiadas uma a uma pelo backend depois que o ticket é criado
// (ver onSubmit); o campo de texto livre sobra como nota opcional do agente
// que está criando o ticket, se ele quiser escrever algo além do que foi
// importado.
const open = (prefill = null) => {
  reset();
  dialogRef.value?.open();

  if (!prefill) return;

  if (prefill.contact) {
    formState.contact = prefill.contact;
    query.value = prefill.contact.name || '';
  }
  if (prefill.subject) formState.subject = prefill.subject;
  if (prefill.selectedMessages?.length) {
    selectedMessages.value = prefill.selectedMessages;
    sourceConversationId.value = prefill.sourceConversationId || null;
    return;
  }
  if (prefill.message) {
    formState.message = prefill.message;
    nextTick(() => {
      if (messageEditorRef.value) {
        messageEditorRef.value.innerHTML = prefill.message;
      }
    });
  }
};

const close = () => {
  dialogRef.value?.close();
};

// Bloco padronizado (Protocolo/Empresa/Serviço/Prioridade/Equipe/Responsável)
// que vira a PRIMEIRA mensagem do ticket quando ele nasce de uma seleção de
// mensagens - dá cara de "ticket" (tipo Movidesk) em vez de parecer uma nota
// solta. Markdown (não HTML) porque é assim que toda mensagem nativa do
// Chatwoot é guardada/renderizada - reaproveita o mesmo pipeline de
// formatação que já sabe exibir **negrito** corretamente, sem escapar nada.
// displayId só existe depois que a conversa é criada (por isso onSubmit
// escreve esse bloco 1x sem ele, pra satisfazer o "precisa ter conteúdo" da
// criação, e reescreve 1x com ele logo em seguida via editMessage).
const buildTicketSummary = displayId => {
  const lines = [];
  if (formState.subject.trim())
    lines.push(`**Assunto:** ${formState.subject.trim()}`);
  if (displayId) lines.push(`**Protocolo:** #${displayId}`);
  const company = formState.contact?.additionalAttributes?.companyName;
  if (company) lines.push(`**Empresa:** ${company}`);
  if (formState.tipo?.id)
    lines.push(`**Tipo de solicitação:** ${formState.tipo.name}`);
  if (formState.servico?.id)
    lines.push(`**Serviço:** ${formState.servico.name}`);
  if (formState.urgencia?.id)
    lines.push(`**Prioridade:** ${formState.urgencia.name}`);
  if (formState.team) lines.push(`**Equipe:** ${formState.team.name}`);
  if (formState.agent) lines.push(`**Responsável:** ${formState.agent.name}`);

  const note = stripPastePreviews(formState.message).trim();
  if (note) lines.push('', `**Nota:**\n${note}`);

  return lines.join('\n');
};

const onSubmit = async () => {
  if (!canSubmit.value) return;
  isSubmitting.value = true;

  const isFromSelection = selectedMessages.value.length > 0;

  let initialContent;
  if (isFromSelection) {
    initialContent = buildTicketSummary(null);
  } else {
    const contentLines = [];
    if (formState.subject.trim()) contentLines.push(formState.subject.trim());
    // O preview <img src="blob:..."> só existe nesta aba - a imagem de verdade
    // já viaja como anexo (attachedFiles), então o texto enviado não deve
    // carregar essa referência local sem sentido pra quem for ler o ticket.
    contentLines.push(stripPastePreviews(formState.message).trim());
    initialContent = contentLines.join('\n\n');
  }

  try {
    const data = await store.dispatch('contactConversations/create', {
      params: {
        inboxId: formState.inbox.id,
        contactId: formState.contact.id,
        message: {
          content: initialContent,
          private: !formState.visibleToClient,
        },
        files: prepareAttachmentPayload(attachedFiles.value, false),
      },
    });

    if (isFromSelection) {
      const summaryMessageId = data.messages?.[0]?.id;
      if (summaryMessageId) {
        await store.dispatch('editMessage', {
          conversationId: data.id,
          messageId: summaryMessageId,
          content: buildTicketSummary(data.id),
        });
      }
      await store.dispatch('copyMessages', {
        conversationId: data.id,
        sourceConversationId: sourceConversationId.value,
        messageIds: selectedMessages.value.map(message => message.id),
      });
    }

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
    if (formState.subject.trim())
      customAttributes.assunto = formState.subject.trim();
    if (formState.servico?.id) customAttributes.servico = formState.servico.id;
    if (formState.tipo?.id)
      customAttributes.tipo_de_solicitao = formState.tipo.id;
    if (formState.prazoResolucao)
      customAttributes.prazo_resolucao = formState.prazoResolucao;
    // Só vai classificação de campo que ainda está aparecendo (trocar o
    // serviço esconde as antigas).
    const customFieldValues = Object.fromEntries(
      classificationItems.value
        .filter(({ field }) => formState.classification[field.key])
        .map(({ field }) => [field.key, formState.classification[field.key]])
    );
    const qaDevValues = {
      liberacoes: formState.liberacoes?.id,
      issue_jira: formState.issueJira.trim(),
      decisao_po: formState.decisaoPo?.id,
      status_da_cobranca: formState.statusCobranca?.id,
      data_entrega: formState.dataEntrega,
      data_de_atualizacao_do_sistema: formState.dataAtualizacaoSistema,
    };
    Object.entries(qaDevValues).forEach(([key, value]) => {
      if (value) customFieldValues[key] = value;
    });
    if (Object.keys(customFieldValues).length)
      customAttributes[CUSTOM_FIELDS_ATTRIBUTE_KEY] = customFieldValues;
    // Vínculo com a conversa de origem, pra quem for ler o ticket depois
    // conseguir voltar pra conversa nativa sem precisar procurar.
    if (isFromSelection && sourceConversationId.value) {
      customAttributes.ticket_interno_origem_conversation_id =
        sourceConversationId.value;
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
    :description="t('NEW_INTERNAL_TICKET_DIALOG.DESCRIPTION')"
    width="full"
    overflow-y-auto
    :is-loading="isSubmitting"
    :disable-confirm-button="!canSubmit"
    @confirm="onSubmit"
  >
    <div
      class="grid grid-cols-1 lg:grid-cols-[30rem_1fr] items-start gap-6 w-full max-h-[75vh] overflow-y-auto pr-1"
    >
      <!-- PATCH LOCAL (fork) - painel de propriedades no padrão da lateral
      (Ações da conversa / QA/DEV), seções separadas por linha. -->
      <div
        class="flex flex-col gap-5 p-5 border rounded-xl border-n-weak bg-n-alpha-1"
      >
        <section class="flex flex-col gap-3">
          <h3 :class="SECTION_TITLE_CLASS">
            <span class="i-lucide-user-round size-3.5" />
            {{ t('NEW_INTERNAL_TICKET_DIALOG.SECTIONS.REQUEST') }}
          </h3>
          <div :class="FIELD_ROW_CLASS">
            <span :class="FIELD_LABEL_CLASS">
              {{ t('NEW_INTERNAL_TICKET_DIALOG.INBOX_LABEL') }}
              <span class="text-n-ruby-9">*</span>
            </span>
            <ComboBox
              :size="FIELD_SIZE"
              :model-value="formState.inbox?.id ?? ''"
              :options="toComboOptions(inboxes)"
              :placeholder="t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')"
              :search-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
              "
              :empty-state="t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')"
              @update:model-value="
                value =>
                  value !== '' && onSelectInbox(fromCombo(inboxes, value))
              "
            />
          </div>
          <div :class="FIELD_ROW_CLASS">
            <span :class="FIELD_LABEL_CLASS">
              {{ t('NEW_INTERNAL_TICKET_DIALOG.REQUESTER_LABEL') }}
              <span class="text-n-ruby-9">*</span>
            </span>
            <div class="relative flex flex-col min-w-0 gap-1">
              <Input
                v-model="query"
                :size="FIELD_SIZE"
                :custom-input-class="FIELD_INPUT_CLASS"
                :placeholder="
                  t('NEW_INTERNAL_TICKET_DIALOG.CONTACT_SEARCH_PLACEHOLDER')
                "
                @input="onSearch"
              />
              <ul
                v-if="results.length"
                class="absolute z-10 w-full mt-1 overflow-y-auto border rounded-md top-9 bg-n-solid-2 border-n-weak max-h-40"
              >
                <li
                  v-for="contact in results"
                  :key="contact.id"
                  class="px-2 py-1.5 text-xs cursor-pointer hover:bg-n-alpha-2"
                  @click="selectContact(contact)"
                >
                  <div class="flex items-center justify-between gap-2">
                    <span class="text-n-slate-12">{{ contact.name }}</span>
                    <span class="truncate text-n-slate-10">
                      {{ contact.email }}
                    </span>
                  </div>
                  <div
                    v-if="contact.additionalAttributes?.companyName"
                    class="text-n-slate-10"
                  >
                    {{ contact.additionalAttributes.companyName }}
                  </div>
                </li>
              </ul>
              <p v-if="formState.contact" class="mb-0 text-xs text-n-teal-11">
                {{ selectedContactLabel }}
              </p>
            </div>
          </div>
        </section>
        <section class="flex flex-col gap-3 pt-5 border-t border-n-weak">
          <h3 :class="SECTION_TITLE_CLASS">
            <span class="i-lucide-folder-tree size-3.5" />
            {{ t('NEW_INTERNAL_TICKET_DIALOG.SECTIONS.CLASSIFICATION') }}
          </h3>
          <div :class="FIELD_ROW_CLASS">
            <span :class="FIELD_LABEL_CLASS">{{
              t('CONVERSATION_SIDEBAR.TIPO_DE_SOLICITACAO_LABEL')
            }}</span>
            <ComboBox
              :size="FIELD_SIZE"
              :model-value="formState.tipo.id"
              :options="toComboOptions(tipoOptions)"
              :placeholder="t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')"
              :search-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
              "
              :empty-state="t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')"
              @update:model-value="
                value =>
                  (formState.tipo =
                    fromCombo(tipoOptions, value) || NONE_OPTION)
              "
            />
          </div>
          <div :class="FIELD_ROW_CLASS">
            <span :class="FIELD_LABEL_CLASS">{{
              t('CONVERSATION_SIDEBAR.SERVICO_LABEL')
            }}</span>
            <ComboBox
              :size="FIELD_SIZE"
              :model-value="formState.servico.id"
              :options="toComboOptions(servicoOptions)"
              :placeholder="t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')"
              :search-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
              "
              :empty-state="t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')"
              @update:model-value="
                value =>
                  onSelectServico(
                    fromCombo(servicoOptions, value) || NONE_OPTION
                  )
              "
            />
          </div>
          <div
            v-for="{ field } in classificationItems"
            :key="field.id"
            :class="FIELD_ROW_CLASS"
          >
            <span :class="FIELD_LABEL_CLASS">{{
              fieldDisplayName(field)
            }}</span>
            <ComboBox
              :size="FIELD_SIZE"
              :model-value="formState.classification[field.key] || ''"
              :options="fieldComboOptions(field)"
              :display-label="formState.classification[field.key] || ''"
              :placeholder="t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')"
              @update:model-value="value => setClassification(field.key, value)"
            />
          </div>
        </section>
        <section class="flex flex-col gap-3 pt-5 border-t border-n-weak">
          <h3 :class="SECTION_TITLE_CLASS">
            <span class="i-lucide-headset size-3.5" />
            {{ t('NEW_INTERNAL_TICKET_DIALOG.SECTIONS.SERVICE') }}
          </h3>
          <div :class="FIELD_ROW_CLASS">
            <span :class="FIELD_LABEL_CLASS">{{
              t('NEW_INTERNAL_TICKET_DIALOG.URGENCIA_LABEL')
            }}</span>
            <ComboBox
              :size="FIELD_SIZE"
              :model-value="formState.urgencia.id"
              :options="toComboOptions(urgenciaOptions)"
              :placeholder="t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')"
              :search-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
              "
              :empty-state="t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')"
              @update:model-value="
                value =>
                  (formState.urgencia =
                    fromCombo(urgenciaOptions, value) || urgenciaOptions[0])
              "
            />
          </div>
          <div :class="FIELD_ROW_CLASS">
            <span :class="FIELD_LABEL_CLASS">{{
              t('NEW_INTERNAL_TICKET_DIALOG.RESPONSIBLE_LABEL')
            }}</span>
            <ComboBox
              :size="FIELD_SIZE"
              :model-value="formState.agent?.id ?? ''"
              :options="toComboOptions(agentsList)"
              :placeholder="t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')"
              :search-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
              "
              :empty-state="t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')"
              @update:model-value="
                value => onSelectAgent(fromCombo(agentsList, value))
              "
            />
          </div>
          <div :class="FIELD_ROW_CLASS">
            <span :class="FIELD_LABEL_CLASS">
              {{ t('NEW_INTERNAL_TICKET_DIALOG.TEAM_LABEL') }}
              <span class="text-n-ruby-9">*</span>
            </span>
            <ComboBox
              :size="FIELD_SIZE"
              :model-value="formState.team?.id ?? ''"
              :options="toComboOptions(teams)"
              :placeholder="t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')"
              :search-placeholder="
                t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
              "
              :empty-state="t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')"
              @update:model-value="
                value => (formState.team = fromCombo(teams, value))
              "
            />
          </div>
          <div :class="FIELD_ROW_CLASS">
            <span :class="FIELD_LABEL_CLASS">{{
              t('NEW_INTERNAL_TICKET_DIALOG.PREVISAO_LABEL')
            }}</span>
            <Input
              v-model="formState.prazoResolucao"
              type="date"
              :size="FIELD_SIZE"
              :custom-input-class="FIELD_INPUT_CLASS"
            />
          </div>
        </section>
        <section class="flex flex-col gap-3 pt-5 border-t border-n-weak">
          <h3 :class="SECTION_TITLE_CLASS">
            <span class="i-lucide-code-xml size-3.5" />
            {{ t('NEW_INTERNAL_TICKET_DIALOG.SECTIONS.QA_DEV') }}
          </h3>
          <div class="flex flex-col gap-3">
            <div :class="FIELD_ROW_CLASS">
              <span :class="FIELD_LABEL_CLASS">{{
                t('NEW_INTERNAL_TICKET_DIALOG.LIBERACOES_LABEL')
              }}</span>
              <ComboBox
                :size="FIELD_SIZE"
                :model-value="formState.liberacoes.id"
                :options="toComboOptions(liberacoesOptions)"
                :placeholder="
                  t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')
                "
                :search-placeholder="
                  t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
                "
                :empty-state="t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')"
                @update:model-value="
                  value =>
                    (formState.liberacoes =
                      fromCombo(liberacoesOptions, value) || NONE_OPTION)
                "
              />
            </div>
            <div :class="FIELD_ROW_CLASS">
              <span :class="FIELD_LABEL_CLASS">{{
                t('NEW_INTERNAL_TICKET_DIALOG.ISSUE_JIRA_LABEL')
              }}</span>
              <Input
                v-model="formState.issueJira"
                type="text"
                :size="FIELD_SIZE"
                :custom-input-class="FIELD_INPUT_CLASS"
              />
            </div>
            <div :class="FIELD_ROW_CLASS">
              <span :class="FIELD_LABEL_CLASS">{{
                t('NEW_INTERNAL_TICKET_DIALOG.DECISAO_PO_LABEL')
              }}</span>
              <ComboBox
                :size="FIELD_SIZE"
                :model-value="formState.decisaoPo.id"
                :options="toComboOptions(decisaoPoOptions)"
                :placeholder="
                  t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')
                "
                :search-placeholder="
                  t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
                "
                :empty-state="t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')"
                @update:model-value="
                  value =>
                    (formState.decisaoPo =
                      fromCombo(decisaoPoOptions, value) || NONE_OPTION)
                "
              />
            </div>
            <div :class="FIELD_ROW_CLASS">
              <span :class="FIELD_LABEL_CLASS">{{
                t('NEW_INTERNAL_TICKET_DIALOG.STATUS_COBRANCA_LABEL')
              }}</span>
              <ComboBox
                :size="FIELD_SIZE"
                :model-value="formState.statusCobranca.id"
                :options="toComboOptions(statusCobrancaOptions)"
                :placeholder="
                  t('NEW_INTERNAL_TICKET_DIALOG.SELECT_PLACEHOLDER')
                "
                :search-placeholder="
                  t('NEW_INTERNAL_TICKET_DIALOG.SEARCH_INPUT_PLACEHOLDER')
                "
                :empty-state="t('NEW_INTERNAL_TICKET_DIALOG.NO_OPTIONS_FOUND')"
                @update:model-value="
                  value =>
                    (formState.statusCobranca =
                      fromCombo(statusCobrancaOptions, value) || NONE_OPTION)
                "
              />
            </div>
            <div :class="FIELD_ROW_CLASS">
              <span :class="FIELD_LABEL_CLASS">{{
                t('NEW_INTERNAL_TICKET_DIALOG.DATA_ENTREGA_LABEL')
              }}</span>
              <Input
                v-model="formState.dataEntrega"
                type="date"
                :size="FIELD_SIZE"
                :custom-input-class="FIELD_INPUT_CLASS"
              />
            </div>
            <div :class="FIELD_ROW_CLASS">
              <span :class="FIELD_LABEL_CLASS">{{
                t('NEW_INTERNAL_TICKET_DIALOG.DATA_ATUALIZACAO_LABEL')
              }}</span>
              <Input
                v-model="formState.dataAtualizacaoSistema"
                :size="FIELD_SIZE"
                :custom-input-class="FIELD_INPUT_CLASS"
                type="datetime-local"
              />
            </div>
          </div>
        </section>
        <section class="flex flex-col gap-3 pt-5 border-t border-n-weak">
          <h3 :class="SECTION_TITLE_CLASS">
            <span class="i-lucide-users-round size-3.5" />
            {{ t('NEW_INTERNAL_TICKET_DIALOG.SECTIONS.CC') }}
          </h3>
          <p class="mb-0 text-xs text-n-slate-11">
            {{ t('NEW_INTERNAL_TICKET_DIALOG.CC_LABEL') }}
          </p>
          <div
            class="flex flex-col overflow-y-auto border divide-y max-h-40 rounded-lg border-n-weak divide-n-weak bg-n-solid-1"
          >
            <label
              v-for="agent in agentsList"
              :key="agent.id"
              class="flex items-center gap-2 px-3 py-2 mb-0 text-xs cursor-pointer text-n-slate-12 hover:bg-n-alpha-2"
            >
              <input
                type="checkbox"
                :checked="formState.ccAgentIds.includes(agent.id)"
                @change="toggleCcAgent(agent.id)"
              />
              {{ agent.name }}
            </label>
          </div>
        </section>
      </div>

      <div class="flex flex-col gap-5">
        <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
          <div class="inline-flex gap-0.5 p-0.5 rounded-lg bg-n-alpha-2">
            <button
              v-for="option in VISIBILITY_OPTIONS"
              :key="option.key"
              type="button"
              class="flex items-center gap-1.5 h-7 px-3 text-xs font-medium transition-colors rounded-md"
              :class="
                formState.visibleToClient === option.visible
                  ? `bg-n-solid-1 shadow-sm ${option.activeClass}`
                  : 'text-n-slate-11 hover:text-n-slate-12'
              "
              @click="formState.visibleToClient = option.visible"
            >
              <span :class="option.icon" class="size-3.5" />
              {{ t(option.label) }}
            </button>
          </div>
          <p class="mb-0 text-xs text-n-slate-10">
            {{
              formState.visibleToClient
                ? t('NEW_INTERNAL_TICKET_DIALOG.VISIBLE_TO_CLIENT_HELP')
                : t('NEW_INTERNAL_TICKET_DIALOG.INTERNAL_TICKET_HELP')
            }}
          </p>
        </div>
        <div class="flex flex-col gap-1.5">
          <span :class="FIELD_LABEL_CLASS">
            {{ t('NEW_INTERNAL_TICKET_DIALOG.SUBJECT_LABEL') }}
          </span>
          <Input
            v-model="formState.subject"
            :placeholder="t('NEW_INTERNAL_TICKET_DIALOG.SUBJECT_PLACEHOLDER')"
          />
        </div>
        <div class="flex flex-col gap-1.5">
          <span :class="FIELD_LABEL_CLASS">
            {{ t('NEW_INTERNAL_TICKET_DIALOG.MESSAGE_LABEL') }}
            <span class="text-n-ruby-9">*</span>
          </span>
          <div
            class="flex flex-col overflow-hidden border rounded-xl border-n-weak bg-n-solid-1 focus-within:border-n-brand"
          >
            <div class="relative">
              <div
                ref="messageEditorRef"
                contenteditable="true"
                class="w-full min-h-[18rem] max-h-[36rem] overflow-y-auto px-4 py-3 text-sm outline-none text-n-slate-12"
                @input="onMessageInput"
                @paste="onPasteMessage"
              />
              <span
                v-if="!messageHasContent"
                class="absolute text-sm pointer-events-none top-3 left-4 text-n-slate-10"
              >
                {{ t('NEW_INTERNAL_TICKET_DIALOG.MESSAGE_PLACEHOLDER') }}
              </span>
            </div>
            <AttachmentPreviews
              v-if="attachedFiles.length"
              class="!max-h-none px-4 pb-3"
              :attachments="attachedFiles"
              @update:attachments="attachedFiles = $event"
            />
            <div
              class="flex items-center justify-between gap-2 px-3 py-2 border-t border-n-weak bg-n-alpha-1"
            >
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
                @input-file="onFileUpload"
              >
                <Button
                  type="button"
                  icon="i-lucide-paperclip"
                  variant="ghost"
                  color="slate"
                  size="sm"
                  :label="t('NEW_INTERNAL_TICKET_DIALOG.ATTACH_BUTTON')"
                />
              </FileUpload>
              <span class="text-xs text-n-slate-10">
                {{ t('NEW_INTERNAL_TICKET_DIALOG.PASTE_HINT') }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-end w-full gap-2">
        <span class="text-xs ltr:mr-auto rtl:ml-auto text-n-slate-10">
          {{ t('NEW_INTERNAL_TICKET_DIALOG.REQUIRED_HINT') }}
        </span>
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
