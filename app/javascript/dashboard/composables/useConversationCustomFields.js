// PATCH LOCAL (fork) - campos adicionais de uma conversa: quais aparecem (regras
// de exibição avaliadas com os valores atuais), o que falta pra resolver e a
// gravação em custom_attributes.campos_adicionais. Usado na lateral da
// conversa (TicketCustomFields.vue), no botão Resolver e no status.
import { computed } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import {
  INTERNAL_TICKETS_INBOX_NAME,
  useTicketCatalog,
} from 'dashboard/composables/useTicketCatalog';
import {
  EMPRESA_ATTRIBUTE_KEY,
  SERVICO_ATTRIBUTE_KEY,
  STATUS_ATENDIMENTO_ATTRIBUTE_KEY,
  TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY,
} from 'dashboard/constants/ticketDetailAttributes';
import wootConstants from 'dashboard/constants/globals';
import {
  CUSTOM_FIELDS_ATTRIBUTE_KEY,
  isEmptyValue,
  missingRequiredFields,
  visibleCustomFields,
} from 'dashboard/helper/ticketFieldRules';

// "Aberto via" do Movidesk pelo canal da caixa. A caixa API é a do Portal.
const CHANNEL_ORIGINS = {
  'Channel::Api': 'cliente',
  'Channel::Whatsapp': 'whatsapp',
  'Channel::Email': 'email',
  'Channel::WebWidget': 'chat',
};

export const conversationOrigin = inbox =>
  inbox?.name === INTERNAL_TICKETS_INBOX_NAME
    ? 'agente'
    : CHANNEL_ORIGINS[inbox?.channel_type] || '';

export function useConversationCustomFields(conversation) {
  const store = useStore();
  const { state, fetchList } = useTicketCatalog();
  const getInbox = useMapGetter('inboxes/getInbox');

  const attributes = computed(
    () => conversation.value?.custom_attributes || {}
  );
  const values = computed(
    () => attributes.value[CUSTOM_FIELDS_ATTRIBUTE_KEY] || {}
  );

  const items = computed(() => {
    const chat = conversation.value;
    if (!chat) return [];
    return visibleCustomFields({
      rules: state.fieldRules,
      fields: state.customFields,
      context: {
        servico: attributes.value[SERVICO_ATTRIBUTE_KEY],
        tipo_de_solicitacao:
          attributes.value[TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY],
        status: attributes.value[STATUS_ATENDIMENTO_ATTRIBUTE_KEY],
        concluded: chat.status === wootConstants.STATUS_TYPE.RESOLVED,
        origem: conversationOrigin(getInbox.value(chat.inbox_id)),
        empresa: attributes.value[EMPRESA_ATTRIBUTE_KEY],
        equipe: chat.meta?.team?.name,
        responsavel: chat.meta?.assignee?.name,
        values: values.value,
      },
    });
  });

  // Obrigatório "na conclusão" que o agente pode preencher e está vazio.
  const missingOnResolve = computed(() =>
    missingRequiredFields(
      items.value.filter(item => item.editable_by_agents),
      values.value,
      ['conclusao']
    )
  );

  const load = () =>
    Promise.all([fetchList('customFields'), fetchList('fieldRules')]);

  const saveValue = (key, value) => {
    const next = { ...values.value };
    if (isEmptyValue(value)) delete next[key];
    else next[key] = value;
    return store.dispatch('updateCustomAttributes', {
      conversationId: conversation.value.id,
      customAttributes: {
        ...attributes.value,
        [CUSTOM_FIELDS_ATTRIBUTE_KEY]: next,
      },
    });
  };

  return { items, values, missingOnResolve, load, saveValue };
}
