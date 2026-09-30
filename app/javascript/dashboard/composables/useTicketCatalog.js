// PATCH LOCAL (fork) - listas dos cadastros de atendimento, carregadas uma vez
// por sessão e compartilhadas entre Configurações e a conversa.
//
// Formato (API):
// - service: { id, parent_id, name, full_name, description, active, ticket_scope
//   ('publico'|'interno'|'ambos'), visible_to_clients, allow_finish,
//   all_categories, category_ids, default_category_id, default_priority
//   ('low'|'medium'|'high'|'urgent'|null), macro_id, position }
// - category: { id, name, active, ticket_scope, allowed_priorities (vazio =
//   todas), position }
// - status: { id, name, base ('novo'|'em_atendimento'|'parado'|'resolvido'|
//   'fechado'|'cancelado'), active, ticket_scope, requires_justification, position }
// - justification: { id, name, active, ticket_scope, status_ids, position }
// - customField: { id, name, key, field_type ('text'|'textarea'|'list'|
//   'single_select'|'multi_select'|'date'|'datetime'), hint, options, active, position }
// - fieldRule: { id, name, active, position, conditions: [{ group ('all'|'any'),
//   attribute, operator, value, field_id }], fields: [{ field_id, columns,
//   visible_to_clients, editable_by_clients, editable_by_agents, required_on }] }
//   (ver helper/ticketFieldRules.js)
//
// A conversa guarda os valores por nome em custom_attributes: servico
// (full_name), categoria, status_atendimento, justificativa; os campos
// adicionais ficam juntos em campos_adicionais, por chave do campo.
import { reactive } from 'vue';
import {
  ticketServicesAPI,
  ticketCategoriesAPI,
  ticketStatusesAPI,
  ticketJustificationsAPI,
  ticketCustomFieldsAPI,
  ticketFieldRulesAPI,
} from 'dashboard/api/ticketCatalog';

export const TICKET_CATALOG_ATTRIBUTE_KEYS = {
  services: 'servico',
  categories: 'tipo_de_solicitao',
  statuses: 'status_atendimento',
  justifications: 'justificativa',
};

// Caixa dos tickets internos (convenção do fork, ver NewInternalTicket.vue).
export const INTERNAL_TICKETS_INBOX_NAME = 'Tickets Internos';

const APIS = {
  services: ticketServicesAPI,
  categories: ticketCategoriesAPI,
  statuses: ticketStatusesAPI,
  justifications: ticketJustificationsAPI,
  customFields: ticketCustomFieldsAPI,
  fieldRules: ticketFieldRulesAPI,
};

// Chave do corpo esperada pelo controller (params.require).
const PAYLOAD_KEYS = {
  services: 'ticket_service',
  categories: 'ticket_category',
  statuses: 'ticket_status',
  justifications: 'ticket_justification',
  customFields: 'ticket_custom_field',
  fieldRules: 'ticket_field_rule',
};

const state = reactive({
  services: [],
  categories: [],
  statuses: [],
  justifications: [],
  customFields: [],
  fieldRules: [],
  loaded: {},
});
const pending = {};

const fetchList = async (kind, { force = false } = {}) => {
  if (state.loaded[kind] && !force) return state[kind];
  pending[kind] ||= APIS[kind]
    .get()
    .then(({ data }) => {
      state[kind] = data.payload;
      state.loaded[kind] = true;
      return state[kind];
    })
    .finally(() => {
      delete pending[kind];
    });
  return pending[kind];
};

const saveRecord = async (kind, record) => {
  const { id, ...attributes } = record;
  const body = { [PAYLOAD_KEYS[kind]]: attributes };
  const { data } = id
    ? await APIS[kind].update(id, body)
    : await APIS[kind].create(body);
  await fetchList(kind, { force: true });
  return data;
};

// Tipo de ticket da conversa: 'interno' na caixa Tickets Internos.
export const conversationTicketScope = inbox =>
  inbox?.name === INTERNAL_TICKETS_INBOX_NAME ? 'interno' : 'publico';

export const matchesTicketScope = (item, scope) =>
  item.ticket_scope === 'ambos' || item.ticket_scope === scope;

export function useTicketCatalog() {
  return { state, fetchList, saveRecord };
}
