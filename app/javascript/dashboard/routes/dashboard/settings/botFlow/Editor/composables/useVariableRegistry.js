import { computed, toValue } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { reachableFlowVariables } from 'dashboard/helper/botFlowHelper';
import { useRecentVariables } from './useRecentVariables';

const humanize = id =>
  id.replace(/_/g, ' ').replace(/^./, char => char.toUpperCase());

// attribute_display_type do Chatwoot (custom attribute) -> tipo interno usado
// pra filtrar/priorizar variáveis por campo (ver VariableSelect/VariablePicker).
const CUSTOM_ATTRIBUTE_TYPE_MAP = {
  text: 'string',
  link: 'string',
  list: 'string',
  number: 'number',
  currency: 'number',
  percent: 'number',
  date: 'date',
  checkbox: 'boolean',
};

const ICON_BY_TYPE = {
  string: 'i-lucide-type',
  number: 'i-lucide-hash',
  date: 'i-lucide-calendar',
  boolean: 'i-lucide-check-square',
  document: 'i-lucide-file-text',
  email: 'i-lucide-mail',
  phone: 'i-lucide-phone',
  object: 'i-lucide-braces',
};

const CATEGORY_ORDER = [
  'flow_captured',
  'integration_cnpj_lookup',
  'integration_receita_cnpj_lookup',
  'contact_standard',
  'contact_custom',
  'conversation_standard',
  'conversation_custom',
  'inbox_standard',
  'agent_standard',
];

// Catálogo dinâmico de variáveis do construtor de bot: junta o que o próprio
// fluxo captura, o que blocos de integração produzem, e o que o Chatwoot já
// sabe sobre contato/conversa (padrão + atributos personalizados, esses
// últimos buscados de verdade na conta - nada aqui é uma lista de exemplo
// fixa no código, exceto os campos que são schema fixo do Chatwoot).
export function useVariableRegistry({
  nodes,
  edges,
  currentNodeId,
  botFlowId,
  sampleContact,
}) {
  const { t } = useI18n();

  const contactAttributes = useMapGetter('attributes/getContactAttributes');
  const conversationAttributes = useMapGetter(
    'attributes/getConversationAttributes'
  );

  const categoryLabel = category =>
    t(`BOT_FLOW.EDITOR.VARIABLES.CATEGORIES.${category.toUpperCase()}`);

  const flowCapturedEntries = computed(() => {
    const nodeList = toValue(nodes) || [];
    const edgeList = toValue(edges) || [];
    const nodeId = toValue(currentNodeId);
    const nodesById = new Map(nodeList.map(node => [node.id, node]));

    return reachableFlowVariables(nodeList, edgeList, nodeId).map(entry => {
      const sourceNode = nodesById.get(entry.sourceNodeId);
      const isIntegrationOutput = !!entry.labelKey;
      const category = isIntegrationOutput
        ? `integration_${sourceNode?.type}`
        : 'flow_captured';
      const blockLabel = sourceNode
        ? t(`BOT_FLOW.EDITOR.NODE_TYPES.${sourceNode.type.toUpperCase()}`)
        : '';

      return {
        id: entry.id,
        label:
          entry.label ||
          (entry.labelKey ? t(entry.labelKey) : humanize(entry.id)),
        technicalHint: entry.id,
        type: entry.type || 'string',
        category,
        categoryLabel: isIntegrationOutput
          ? blockLabel
          : categoryLabel('flow_captured'),
        originLabel: t('BOT_FLOW.EDITOR.VARIABLES.ORIGIN.FLOW_BLOCK', {
          blockLabel,
        }),
        icon: ICON_BY_TYPE[entry.type || 'string'],
      };
    });
  });

  const contactStandardEntries = computed(() => [
    {
      id: 'contact.name',
      label: t('BOT_FLOW.EDITOR.VARIABLES.CONTACT.NAME'),
      technicalHint: 'contact.name',
      type: 'string',
      category: 'contact_standard',
      categoryLabel: categoryLabel('contact_standard'),
      originLabel: t('BOT_FLOW.EDITOR.VARIABLES.ORIGIN.CHATWOOT_STANDARD'),
      icon: 'i-lucide-user',
      sampleValue: toValue(sampleContact)?.name,
    },
    {
      id: 'contact.email',
      label: t('BOT_FLOW.EDITOR.VARIABLES.CONTACT.EMAIL'),
      technicalHint: 'contact.email',
      type: 'email',
      category: 'contact_standard',
      categoryLabel: categoryLabel('contact_standard'),
      originLabel: t('BOT_FLOW.EDITOR.VARIABLES.ORIGIN.CHATWOOT_STANDARD'),
      icon: ICON_BY_TYPE.email,
      sampleValue: toValue(sampleContact)?.email,
    },
    {
      id: 'contact.phone_number',
      label: t('BOT_FLOW.EDITOR.VARIABLES.CONTACT.PHONE_NUMBER'),
      technicalHint: 'contact.phone_number',
      type: 'phone',
      category: 'contact_standard',
      categoryLabel: categoryLabel('contact_standard'),
      originLabel: t('BOT_FLOW.EDITOR.VARIABLES.ORIGIN.CHATWOOT_STANDARD'),
      icon: ICON_BY_TYPE.phone,
      sampleValue: toValue(sampleContact)?.phoneNumber,
    },
    {
      id: 'contact.identifier',
      label: t('BOT_FLOW.EDITOR.VARIABLES.CONTACT.IDENTIFIER'),
      technicalHint: 'contact.identifier',
      type: 'string',
      category: 'contact_standard',
      categoryLabel: categoryLabel('contact_standard'),
      originLabel: t('BOT_FLOW.EDITOR.VARIABLES.ORIGIN.CHATWOOT_STANDARD'),
      icon: 'i-lucide-fingerprint',
      sampleValue: toValue(sampleContact)?.identifier,
    },
  ]);

  const contactCustomEntries = computed(() =>
    contactAttributes.value.map(attribute => ({
      id: `contact.custom_attributes.${attribute.attributeKey}`,
      label: attribute.attributeDisplayName,
      technicalHint: `contact.custom_attributes.${attribute.attributeKey}`,
      type:
        CUSTOM_ATTRIBUTE_TYPE_MAP[attribute.attributeDisplayType] || 'string',
      category: 'contact_custom',
      categoryLabel: categoryLabel('contact_custom'),
      originLabel: t('BOT_FLOW.EDITOR.VARIABLES.ORIGIN.CHATWOOT_CUSTOM'),
      icon: ICON_BY_TYPE[
        CUSTOM_ATTRIBUTE_TYPE_MAP[attribute.attributeDisplayType] || 'string'
      ],
      sampleValue:
        toValue(sampleContact)?.customAttributes?.[attribute.attributeKey],
    }))
  );

  const conversationStandardEntries = computed(() => [
    {
      id: 'conversation.id',
      label: t('BOT_FLOW.EDITOR.VARIABLES.CONVERSATION.ID'),
      technicalHint: 'conversation.id',
      type: 'number',
      category: 'conversation_standard',
      categoryLabel: categoryLabel('conversation_standard'),
      originLabel: t('BOT_FLOW.EDITOR.VARIABLES.ORIGIN.CHATWOOT_STANDARD'),
      icon: 'i-lucide-hash',
    },
    {
      id: 'conversation.status',
      label: t('BOT_FLOW.EDITOR.VARIABLES.CONVERSATION.STATUS'),
      technicalHint: 'conversation.status',
      type: 'string',
      category: 'conversation_standard',
      categoryLabel: categoryLabel('conversation_standard'),
      originLabel: t('BOT_FLOW.EDITOR.VARIABLES.ORIGIN.CHATWOOT_STANDARD'),
      icon: 'i-lucide-circle-dot',
    },
    {
      id: 'conversation.priority',
      label: t('BOT_FLOW.EDITOR.VARIABLES.CONVERSATION.PRIORITY'),
      technicalHint: 'conversation.priority',
      type: 'string',
      category: 'conversation_standard',
      categoryLabel: categoryLabel('conversation_standard'),
      originLabel: t('BOT_FLOW.EDITOR.VARIABLES.ORIGIN.CHATWOOT_STANDARD'),
      icon: 'i-lucide-flag',
    },
  ]);

  const conversationCustomEntries = computed(() =>
    conversationAttributes.value.map(attribute => ({
      id: `conversation.custom_attributes.${attribute.attributeKey}`,
      label: attribute.attributeDisplayName,
      technicalHint: `conversation.custom_attributes.${attribute.attributeKey}`,
      type:
        CUSTOM_ATTRIBUTE_TYPE_MAP[attribute.attributeDisplayType] || 'string',
      category: 'conversation_custom',
      categoryLabel: categoryLabel('conversation_custom'),
      originLabel: t('BOT_FLOW.EDITOR.VARIABLES.ORIGIN.CHATWOOT_CUSTOM'),
      icon: ICON_BY_TYPE[
        CUSTOM_ATTRIBUTE_TYPE_MAP[attribute.attributeDisplayType] || 'string'
      ],
    }))
  );

  const inboxAgentEntries = computed(() => [
    {
      id: 'inbox.name',
      label: t('BOT_FLOW.EDITOR.VARIABLES.INBOX.NAME'),
      technicalHint: 'inbox.name',
      type: 'string',
      category: 'inbox_standard',
      categoryLabel: categoryLabel('inbox_standard'),
      originLabel: t('BOT_FLOW.EDITOR.VARIABLES.ORIGIN.CHATWOOT_STANDARD'),
      icon: 'i-lucide-inbox',
    },
    {
      id: 'agent.name',
      label: t('BOT_FLOW.EDITOR.VARIABLES.AGENT.NAME'),
      technicalHint: 'agent.name',
      type: 'string',
      category: 'agent_standard',
      categoryLabel: categoryLabel('agent_standard'),
      originLabel: t('BOT_FLOW.EDITOR.VARIABLES.ORIGIN.CHATWOOT_STANDARD'),
      icon: 'i-lucide-user-round',
    },
    {
      id: 'agent.email',
      label: t('BOT_FLOW.EDITOR.VARIABLES.AGENT.EMAIL'),
      technicalHint: 'agent.email',
      type: 'email',
      category: 'agent_standard',
      categoryLabel: categoryLabel('agent_standard'),
      originLabel: t('BOT_FLOW.EDITOR.VARIABLES.ORIGIN.CHATWOOT_STANDARD'),
      icon: ICON_BY_TYPE.email,
    },
  ]);

  const catalog = computed(() => {
    const entries = [
      ...flowCapturedEntries.value,
      ...contactStandardEntries.value,
      ...contactCustomEntries.value,
      ...conversationStandardEntries.value,
      ...conversationCustomEntries.value,
      ...inboxAgentEntries.value,
    ];
    return entries.sort(
      (a, b) =>
        CATEGORY_ORDER.indexOf(a.category) - CATEGORY_ORDER.indexOf(b.category)
    );
  });

  const { recentIds, recordUsage } = useRecentVariables(toValue(botFlowId));

  const resolve = id => catalog.value.find(entry => entry.id === id) || null;
  const isStale = id => !!id && !resolve(id);

  return {
    catalog,
    recentIds,
    recordUsage,
    resolve,
    isStale,
    contactAttributeKeys: computed(() =>
      contactAttributes.value.map(a => a.attributeKey)
    ),
    conversationAttributeKeys: computed(() =>
      conversationAttributes.value.map(a => a.attributeKey)
    ),
  };
}
