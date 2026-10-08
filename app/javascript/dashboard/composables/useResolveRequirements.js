// PATCH LOCAL (fork) - o que falta pra resolver uma conversa, igual ao servidor
// (Conversations::ResolveRequirementsService): "Ações da conversa", campos
// adicionais obrigatórios na conclusão e o motivo de encerramento. O botão
// Resolver e as macros que resolvem usam esta mesma conta.
import { computed, ref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useConversationCustomFields } from 'dashboard/composables/useConversationCustomFields';
import { MOTIVO_ENCERRAMENTO_ATTRIBUTE_KEY } from 'dashboard/constants/ticketDetailAttributes';
import { missingConversationActions } from 'dashboard/helper/conversationRequiredActions';
import { isEmptyValue } from 'dashboard/helper/ticketFieldRules';

export function useResolveRequirements() {
  const conversationById = useMapGetter('getConversationById');
  const conversationAttributes = useMapGetter(
    'attributes/getConversationAttributes'
  );
  const teams = useMapGetter('teams/getTeams');

  const targetId = ref(null);
  const target = computed(() => conversationById.value(targetId.value));
  const { missingOnResolve, load } = useConversationCustomFields(target);

  // O motivo de encerramento é pedido sempre ao resolver (o Portal depende
  // dele nos relatórios), sem depender do recurso pago de atributos
  // obrigatórios do Chatwoot.
  const closeReasonAttribute = computed(() => {
    const attribute = (conversationAttributes.value || []).find(
      item => item.attributeKey === MOTIVO_ENCERRAMENTO_ATTRIBUTE_KEY
    );
    if (!attribute) return null;
    return {
      ...attribute,
      value: attribute.attributeKey,
      label: attribute.attributeDisplayName,
      type: attribute.attributeDisplayType,
      attributeValues: attribute.attributeValues,
    };
  });

  // { actions: [{ key, label }], customFields: [nome], closeReason: atributo|null }
  const missingFor = async (conversation, nativeLabels) => {
    targetId.value = conversation.id;
    await load();
    const closeReason = closeReasonAttribute.value;
    const closeReasonMissing =
      closeReason &&
      isEmptyValue(conversation.custom_attributes?.[closeReason.value]);
    return {
      actions: missingConversationActions(conversation, {
        attributes: conversationAttributes.value || [],
        hasTeams: (teams.value || []).length > 0,
        nativeLabels,
      }),
      customFields: missingOnResolve.value.map(item => item.field.name),
      closeReason: closeReasonMissing ? closeReason : null,
    };
  };

  return { missingFor };
}
