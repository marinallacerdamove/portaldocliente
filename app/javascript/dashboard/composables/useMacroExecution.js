import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert, useTrack } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useConversationRequiredAttributes } from 'dashboard/composables/useConversationRequiredAttributes';
import { useResolveRequirements } from 'dashboard/composables/useResolveRequirements';
import { CONVERSATION_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

// change_status is not offered by the macro builder, but the API accepts it and
// it resolves the conversation just like resolve_conversation does. Its param is
// stored as raw JSON, so the status can be the enum name or its integer value.
const RESOLVED_STATUSES = ['resolved', 1];

// PATCH LOCAL (fork) - ações que rodam só no navegador (o servidor ignora).
const CLIENT_ACTIONS = ['fill_reply'];

const hasServerActions = macro =>
  macro.actions.some(({ action_name: name }) => !CLIENT_ACTIONS.includes(name));

// "Texto da resposta": vai pro editor de resposta (ReplyBox) pro atendente
// completar antes de enviar.
const fillReplyEditor = macro =>
  macro.actions
    .filter(({ action_name: name }) => name === 'fill_reply')
    .forEach(({ action_params: [content, mode] }) =>
      emitter.emit(BUS_EVENTS.MACRO_FILL_REPLY, { content, mode })
    );

const resolvesConversation = macro =>
  macro.actions.some(
    ({ action_name: name, action_params: params }) =>
      name === 'resolve_conversation' ||
      (name === 'change_status' && RESOLVED_STATUSES.includes(params?.[0]))
  );

/**
 * Runs a macro against a conversation, holding back the ones that resolve it until
 * the required custom attributes are filled in.
 *
 * `execute` returns the attributes to prompt for when the caller has to open the
 * modal first, and null once the macro has been handed off.
 */
export function useMacroExecution() {
  const store = useStore();
  const { t } = useI18n();
  const { checkMissingAttributes } = useConversationRequiredAttributes();
  const { missingFor } = useResolveRequirements();

  const conversationById = useMapGetter('getConversationById');

  const executingMacroId = ref(null);
  const pendingExecution = ref(null);

  const customAttributesFor = conversationId =>
    conversationById.value(conversationId)?.custom_attributes || {};

  // PATCH LOCAL (fork) - o servidor não resolve com o que o botão Resolver
  // cobra faltando (Macros::ResolveRequirements): a macro roda sem resolver e
  // a tela diz o que falta.
  const missingToResolve = async ({ macro, conversationId }) => {
    const conversation = conversationById.value(conversationId);
    if (!conversation || !resolvesConversation(macro)) return [];
    const { actions, customFields, closeReason } = await missingFor(
      conversation,
      {
        priority: t('CONVERSATION.PRIORITY.TITLE'),
        assignee: t('CONVERSATION_SIDEBAR.ASSIGNEE_LABEL'),
        team: t('CONVERSATION_SIDEBAR.TEAM_LABEL'),
      }
    );
    return [
      ...actions.map(item => item.label),
      ...customFields,
      ...(closeReason ? [closeReason.label] : []),
    ];
  };

  const runMacro = async (execution, skippedResolve = false) => {
    const { macro, conversationId, silent, successMessage } = execution;
    try {
      executingMacroId.value = macro.id;
      const blocked = skippedResolve ? [] : await missingToResolve(execution);
      await store.dispatch('macros/execute', {
        macroId: macro.id,
        conversationIds: [conversationId],
      });
      useTrack(CONVERSATION_EVENTS.EXECUTED_A_MACRO);
      if (blocked.length) {
        useAlert(
          t('MACROS.EXECUTE.RESOLVE_BLOCKED', { fields: blocked.join(', ') })
        );
        return;
      }
      if (silent) {
        if (successMessage) useAlert(successMessage);
        return;
      }
      useAlert(
        skippedResolve
          ? t('MACROS.EXECUTE.EXECUTED_WITHOUT_RESOLVING')
          : t('MACROS.EXECUTE.EXECUTED_SUCCESSFULLY')
      );
    } catch (error) {
      useAlert(t('MACROS.ERROR'));
    } finally {
      executingMacroId.value = null;
    }
  };

  // PATCH LOCAL (fork) - `silent`: sem o aviso padrão (macro disparada pelo
  // serviço); `successMessage` é o aviso dela, dado depois da execução. Erro e
  // resolver travado continuam avisando.
  const execute = (
    macro,
    conversationId,
    { silent = false, successMessage = '' } = {}
  ) => {
    const execution = { macro, conversationId, silent, successMessage };

    fillReplyEditor(macro);
    if (!hasServerActions(macro)) return null;

    if (!resolvesConversation(macro)) {
      runMacro(execution);
      return null;
    }

    const customAttributes = customAttributesFor(conversationId);
    const { hasMissing, missing } = checkMissingAttributes(customAttributes);
    if (!hasMissing) {
      runMacro(execution);
      return null;
    }

    pendingExecution.value = execution;
    return { missing, customAttributes };
  };

  const submitPendingAttributes = async ({ attributes }) => {
    const execution = pendingExecution.value;
    pendingExecution.value = null;

    try {
      await store.dispatch('mergeCustomAttributes', {
        conversationId: execution.conversationId,
        changes: attributes,
      });
    } catch (error) {
      useAlert(t('CUSTOM_ATTRIBUTES.FORM.UPDATE.ERROR'));
      return;
    }

    runMacro(execution);
  };

  // Dismissing the modal still runs the macro, the backend leaves the
  // conversation unresolved while the required attributes are empty.
  const dismissPendingAttributes = () => {
    if (!pendingExecution.value) return;

    runMacro(pendingExecution.value, true);
    pendingExecution.value = null;
  };

  return {
    executingMacroId,
    execute,
    submitPendingAttributes,
    dismissPendingAttributes,
  };
}
