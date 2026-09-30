import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert, useTrack } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useConversationRequiredAttributes } from 'dashboard/composables/useConversationRequiredAttributes';
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

  const conversationById = useMapGetter('getConversationById');

  const executingMacroId = ref(null);
  const pendingExecution = ref(null);

  const customAttributesFor = conversationId =>
    conversationById.value(conversationId)?.custom_attributes || {};

  const runMacro = async (
    { macro, conversationId, silent },
    skippedResolve = false
  ) => {
    try {
      executingMacroId.value = macro.id;
      await store.dispatch('macros/execute', {
        macroId: macro.id,
        conversationIds: [conversationId],
      });
      useTrack(CONVERSATION_EVENTS.EXECUTED_A_MACRO);
      if (silent) return;
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

  // PATCH LOCAL (fork) - `silent`: quem chama mostra o próprio aviso (macro
  // disparada pelo serviço). Erro continua avisando.
  const execute = (macro, conversationId, { silent = false } = {}) => {
    const execution = { macro, conversationId, silent };

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
      await store.dispatch('updateCustomAttributes', {
        conversationId: execution.conversationId,
        customAttributes: {
          ...customAttributesFor(execution.conversationId),
          ...attributes,
        },
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
