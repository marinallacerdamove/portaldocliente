// PATCH LOCAL (fork) - regras puras dos cadastros de atendimento: árvore de
// serviços, registro novo de cada tipo e o corpo enviado pra API.
import { CATALOG_KINDS } from './constants';
import { OPTION_FIELD_TYPES } from 'dashboard/helper/ticketFieldRules';

// Serviços em árvore: pai antes dos filhos, cada um com a profundidade (depth)
// pra indentar. A API já manda na ordem (position, name); a ordem entre
// irmãos é mantida. Serviço cujo pai não veio na lista entra como raiz.
export const buildServiceTree = services => {
  const ids = new Set(services.map(service => service.id));
  const childrenOf = new Map();
  services.forEach(service => {
    const parentId = ids.has(service.parent_id) ? service.parent_id : null;
    if (!childrenOf.has(parentId)) childrenOf.set(parentId, []);
    childrenOf.get(parentId).push(service);
  });

  const tree = [];
  const visit = (parentId, depth) => {
    (childrenOf.get(parentId) || []).forEach(service => {
      tree.push({ ...service, depth });
      visit(service.id, depth + 1);
    });
  };
  visit(null, 0);
  return tree;
};

// O próprio serviço e todos os descendentes: não podem ser escolhidos como pai
// (viraria ciclo).
export const serviceSubtreeIds = (services, serviceId) => {
  const subtree = new Set();
  if (!serviceId) return subtree;
  const pending = [serviceId];
  while (pending.length) {
    const id = pending.pop();
    subtree.add(id);
    services
      .filter(service => service.parent_id === id)
      .forEach(service => pending.push(service.id));
  }
  return subtree;
};

const COMMON_DEFAULTS = { name: '', active: true };

const KIND_DEFAULTS = {
  services: {
    description: '',
    parent_id: null,
    visible_to_clients: true,
    allow_finish: true,
    all_categories: true,
    category_ids: [],
    default_category_id: null,
    default_priority: null,
    macro_id: null,
  },
  categories: { allowed_priorities: [] },
  statuses: { base: 'novo', requires_justification: false },
  justifications: { status_ids: [] },
  customFields: { field_type: 'text', hint: '', options: [] },
  fieldRules: { conditions: [], fields: [] },
};

export const newCatalogRecord = kind => ({
  ...COMMON_DEFAULTS,
  ...(CATALOG_KINDS[kind].hasScope === false ? {} : { ticket_scope: 'ambos' }),
  ...KIND_DEFAULTS[kind],
});

// Cópia editável de um registro da API: campo que veio null e tem padrão não
// nulo (ex.: descrição vazia) volta pro padrão, pra caber no campo do form.
export const editableCatalogRecord = (kind, record) => {
  const defaults = newCatalogRecord(kind);
  const copy = { ...defaults, ...JSON.parse(JSON.stringify(record)) };
  Object.entries(defaults).forEach(([key, value]) => {
    if (copy[key] === null && value !== null) copy[key] = value;
  });
  return copy;
};

// Só o que o controller aceita (full_name, key e position não vão). Serviço
// com "Todas as categorias" não guarda escolha de categoria; campo sem lista
// não guarda opções.
export const catalogPayload = (kind, record) => {
  const keys = ['id', ...Object.keys(newCatalogRecord(kind))];
  const payload = Object.fromEntries(
    keys.filter(key => key in record).map(key => [key, record[key]])
  );
  if (kind === 'services' && payload.all_categories) payload.category_ids = [];
  if (
    kind === 'customFields' &&
    !OPTION_FIELD_TYPES.includes(payload.field_type)
  )
    payload.options = [];
  return payload;
};
