// PATCH LOCAL (fork) - campos de "Ações da conversa" obrigatórios pra
// resolver, em qualquer canal. Campo de atributo só é cobrado quando a conta
// tem o atributo cadastrado, e o time só quando a conta tem time (senão o
// Resolver ficaria travado sem ter como preencher). A ordem é a da lateral.
import {
  EMPRESA_ATTRIBUTE_KEY,
  TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY,
  SERVICO_ATTRIBUTE_KEY,
} from 'dashboard/constants/ticketDetailAttributes';

export const REQUIRED_ACTION_ATTRIBUTE_KEYS = Object.freeze([
  EMPRESA_ATTRIBUTE_KEY,
  TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY,
  SERVICO_ATTRIBUTE_KEY,
]);

const isBlank = value => value == null || String(value).trim() === '';

// Devolve [{ key, label }] do que falta; label do atributo vem do cadastro
// (attributeDisplayName), os nativos vêm do i18n passado em nativeLabels.
export const missingConversationActions = (
  conversation,
  { attributes = [], hasTeams = false, nativeLabels = {} } = {}
) => {
  const customAttributes = conversation?.custom_attributes || {};
  const missing = REQUIRED_ACTION_ATTRIBUTE_KEYS.flatMap(key => {
    const definition = attributes.find(item => item.attributeKey === key);
    if (!definition || !isBlank(customAttributes[key])) return [];
    return [{ key, label: definition.attributeDisplayName }];
  });

  if (isBlank(conversation?.priority))
    missing.push({ key: 'priority', label: nativeLabels.priority });
  if (!conversation?.meta?.assignee)
    missing.push({ key: 'assignee', label: nativeLabels.assignee });
  if (hasTeams && !conversation?.meta?.team)
    missing.push({ key: 'team', label: nativeLabels.team });

  return missing;
};
