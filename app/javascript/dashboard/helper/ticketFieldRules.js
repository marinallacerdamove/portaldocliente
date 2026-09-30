// PATCH LOCAL (fork) - regras de exibição dos campos adicionais (Movidesk:
// Regras para exibição). Uma regra aparece quando TODAS as condições do grupo
// "all" batem e, se o grupo "any" tiver condição, pelo menos uma delas. Os
// campos das regras que batem são os que o ticket mostra. O Portal tem uma
// cópia desta mesma lógica (frontend/src/utils/ticketFieldRules.js), as duas
// precisam avaliar igual.
//
// context: { servico, tipo_de_solicitacao, status, concluded, origem, empresa,
//   equipe, responsavel, values } - values = campos_adicionais (chave -> valor).

export const CUSTOM_FIELDS_ATTRIBUTE_KEY = 'campos_adicionais';

// Status especial do Movidesk: qualquer status que não encerra o ticket.
export const STATUS_NOT_CONCLUDED = '__nao_concluido';

export const OPTION_FIELD_TYPES = ['list', 'single_select', 'multi_select'];

export const CONDITION_ATTRIBUTES = [
  'servico',
  'tipo_de_solicitacao',
  'status',
  'campo',
  'origem',
  'empresa',
  'equipe',
  'responsavel',
];

export const CONDITION_OPERATORS = ['equal_to', 'not_equal_to', 'is_present'];

export const ORIGINS = ['cliente', 'agente', 'chat', 'whatsapp', 'email'];

export const REQUIRED_ON = [
  'nao_exigir',
  'abertura_agente',
  'abertura_cliente',
  'abertura',
  'conclusao',
];

export const isEmptyValue = value =>
  value === undefined ||
  value === null ||
  (Array.isArray(value) ? value.length === 0 : String(value).trim() === '');

const conditionMatches = (condition, context, visibleIds, fieldsById) => {
  const { attribute, operator, value } = condition;
  if (attribute === 'status' && value === STATUS_NOT_CONCLUDED) {
    if (operator === 'is_present') return true;
    return operator === 'equal_to' ? !context.concluded : !!context.concluded;
  }

  let current = context[attribute];
  if (attribute === 'campo') {
    // Campo escondido não conta: senão um valor antigo (de antes de trocar o
    // serviço, por exemplo) manteria a cascata aberta.
    if (!visibleIds.has(condition.field_id)) return false;
    current = (context.values || {})[fieldsById.get(condition.field_id).key];
  }
  if (operator === 'is_present') return !isEmptyValue(current);

  // Seleção múltipla: "igual a" = a opção está marcada.
  const currentValues = Array.isArray(current) ? current : [current];
  const hit = currentValues.some(item => String(item ?? '').trim() === value);
  return operator === 'equal_to' ? hit : !hit;
};

const ruleMatches = (rule, context, visibleIds, fieldsById) => {
  const matches = condition =>
    conditionMatches(condition, context, visibleIds, fieldsById);
  const all = rule.conditions.filter(condition => condition.group === 'all');
  const any = rule.conditions.filter(condition => condition.group === 'any');
  return all.every(matches) && (!any.length || any.some(matches));
};

const sameIds = (a, b) => a.size === b.size && [...a].every(id => b.has(id));

// Campos das regras que batem, considerando visíveis só os campos visibleIds.
const itemsFor = (activeRules, context, visibleIds, fieldsById) => {
  const ids = new Set();
  const items = activeRules
    .filter(rule => ruleMatches(rule, context, visibleIds, fieldsById))
    .flatMap(rule =>
      rule.fields.flatMap(ruleField => {
        const field = fieldsById.get(ruleField.field_id);
        if (!field || ids.has(field.id)) return [];
        ids.add(field.id);
        return [{ ...ruleField, field }];
      })
    );
  return { items, ids };
};

// Campos que o ticket mostra, na ordem das regras e, dentro da regra, na
// ordem dos campos: [{ field, columns, visible_to_clients, editable_by_clients,
// editable_by_agents, required_on }]. Campo em mais de uma regra fica com a
// configuração da primeira. Repete até estabilizar, porque mostrar um campo
// pode fazer outra regra (condição nesse campo) passar a bater.
export const visibleCustomFields = ({ rules, fields, context }) => {
  const fieldsById = new Map(
    fields.filter(field => field.active).map(field => [field.id, field])
  );
  const activeRules = rules.filter(rule => rule.active);
  let visibleIds = new Set();
  let result = itemsFor(activeRules, context, visibleIds, fieldsById);
  for (
    let round = 0;
    round < activeRules.length && !sameIds(result.ids, visibleIds);
    round += 1
  ) {
    visibleIds = result.ids;
    result = itemsFor(activeRules, context, visibleIds, fieldsById);
  }
  return result.items;
};

// Obrigatórios ainda vazios pro momento (ex. ['conclusao'] ao resolver).
export const missingRequiredFields = (items, values, moments) =>
  items.filter(
    item =>
      moments.includes(item.required_on) &&
      isEmptyValue((values || {})[item.field.key])
  );
