// PATCH LOCAL (fork) - em que lugar da lateral cada campo adicional aparece.
// A regra de exibição decide SE o campo aparece; aqui só decide ONDE, pela
// chave do campo (gerada do nome na criação e fixa depois, ver
// TicketCustomField). Classificação/Tipo do serviço ficam em "Ações da
// conversa" logo depois de Serviço; os campos do fluxo PO em "Ações do
// QA/DEV"; o resto (checklists etc.) em "Detalhes do ticket".
export const FIELD_GROUPS = Object.freeze({
  CLASSIFICATION: 'classification',
  QA_DEV: 'qaDev',
  OTHER: 'other',
});

// Prefixos na ordem em que aparecem (classificação antes do tipo).
const CLASSIFICATION_KEY_PREFIXES = [
  'classificacao_do_servico',
  'tipo_do_servico',
];

// Na ordem em que aparecem.
export const QA_DEV_FIELD_KEYS = Object.freeze([
  'liberacoes',
  'issue_jira',
  'decisao_po',
  'status_da_cobranca',
  'data_entrega',
  'data_de_atualizacao_do_sistema',
]);

const classificationRank = key =>
  CLASSIFICATION_KEY_PREFIXES.findIndex(prefix => key.startsWith(prefix));

export const fieldGroup = key => {
  if (classificationRank(key) !== -1) return FIELD_GROUPS.CLASSIFICATION;
  if (QA_DEV_FIELD_KEYS.includes(key)) return FIELD_GROUPS.QA_DEV;
  return FIELD_GROUPS.OTHER;
};

const RANKS = {
  [FIELD_GROUPS.CLASSIFICATION]: classificationRank,
  [FIELD_GROUPS.QA_DEV]: key => QA_DEV_FIELD_KEYS.indexOf(key),
  [FIELD_GROUPS.OTHER]: () => 0,
};

// Itens visíveis (visibleCustomFields) de um grupo, na ordem do grupo; empate
// mantém a ordem das regras (sort é estável).
export const itemsInGroup = (items, group) =>
  items
    .filter(item => fieldGroup(item.field.key) === group)
    .sort((a, b) => RANKS[group](a.field.key) - RANKS[group](b.field.key));
