// Conversation custom attribute keys shown in their own "Detalhes do Atendimento"
// sidebar section instead of the generic "Informação da conversa" panel.
// Order here controls render order (see CustomAttributes.vue's includeKeys sort).
export const TICKET_DETAIL_ATTRIBUTE_KEYS = Object.freeze([
  'categoria',
  'issue_jira',
  'data_entrega',
  'data_atualizacao_sistema',
  'decisao_po',
  'liberacoes',
  'status_cobranca',
]);

// Conversation custom attribute keys that come from the Portal do Cliente
// ticket sync, shown in their own "Informações do Portal do Cliente" section.
export const PORTAL_INFO_ATTRIBUTE_KEYS = Object.freeze([
  'produto',
  'sla_horas',
  'prazo_resolucao',
  'ticket_id_externo',
  'tipo_de_solicitao',
  'visivel_parceiro',
  'motivo_encerramento',
]);

// Rendered inline in ConversationAction.vue ("Ações da conversa"), alongside
// Assignee/Team/Priority — still needs excluding from "Informação da conversa".
export const SERVICO_ATTRIBUTE_KEY = 'servico';

// Rendered inline in ConversationAction.vue as the Ticket Pai/Filhos links —
// raw values, never meant to appear as generic custom-attribute fields.
export const TICKET_LINK_ATTRIBUTE_KEYS = Object.freeze([
  'ticket_pai_id',
  'ticket_filhos_ids',
]);

// Every conversation_attribute key that has a dedicated home elsewhere in the
// sidebar — used to decide whether "Informação da conversa" has anything
// left to show at all.
export const ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS = Object.freeze([
  ...TICKET_DETAIL_ATTRIBUTE_KEYS,
  ...PORTAL_INFO_ATTRIBUTE_KEYS,
  SERVICO_ATTRIBUTE_KEY,
  ...TICKET_LINK_ATTRIBUTE_KEYS,
]);
