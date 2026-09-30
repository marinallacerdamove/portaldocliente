// PATCH LOCAL (fork) - cadastros de atendimento em Configurações (paridade com
// o Movidesk): Serviços, Categorias, Status, Justificativas, Campos adicionais
// e Regras de exibição. Um único par de
// telas (lista e ficha) atende os quatro; aqui fica o que muda de um pro outro.

export const TICKET_SCOPES = ['publico', 'interno', 'ambos'];

export const PRIORITIES = ['low', 'medium', 'high', 'urgent'];

// Tipo do status do Movidesk; o backend traduz pro status da conversa.
export const STATUS_BASES = [
  'novo',
  'em_atendimento',
  'parado',
  'resolvido',
  'fechado',
  'cancelado',
];

export const FIELD_TYPES = [
  'text',
  'textarea',
  'list',
  'single_select',
  'multi_select',
  'date',
  'datetime',
];

export const ACTIVE_FILTERS = ['active', 'inactive', 'all'];

// i18n: chave em TICKET_CATALOG; routeBase: prefixo dos nomes de rota;
// hasScope: tem "Tipo de ticket" (campos e regras não têm, como no Movidesk).
export const CATALOG_KINDS = {
  services: {
    i18nKey: 'SERVICES',
    routeBase: 'ticket_catalog_services',
    path: 'ticket_services',
    icon: 'i-lucide-folder-tree',
  },
  categories: {
    i18nKey: 'CATEGORIES',
    routeBase: 'ticket_catalog_categories',
    path: 'ticket_categories',
    icon: 'i-lucide-tags',
  },
  statuses: {
    i18nKey: 'STATUSES',
    routeBase: 'ticket_catalog_statuses',
    path: 'ticket_statuses',
    icon: 'i-lucide-flag',
  },
  justifications: {
    i18nKey: 'JUSTIFICATIONS',
    routeBase: 'ticket_catalog_justifications',
    path: 'ticket_justifications',
    icon: 'i-lucide-message-square-quote',
  },
  customFields: {
    i18nKey: 'CUSTOM_FIELDS',
    routeBase: 'ticket_catalog_custom_fields',
    path: 'ticket_custom_fields',
    icon: 'i-lucide-text-cursor-input',
    hasScope: false,
  },
  fieldRules: {
    i18nKey: 'FIELD_RULES',
    routeBase: 'ticket_catalog_field_rules',
    path: 'ticket_field_rules',
    icon: 'i-lucide-list-checks',
    hasScope: false,
  },
};

export const catalogRouteName = (kind, page) =>
  `${CATALOG_KINDS[kind].routeBase}_${page}`;
