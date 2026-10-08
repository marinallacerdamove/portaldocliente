// PATCH LOCAL (fork) - gravações de ticket na conversa (ver api/tickets.js).
import TicketsAPI from '../../../../api/tickets';
import mutationTypes from '../../../mutation-types';
import { isEmptyValue } from 'dashboard/helper/ticketFieldRules';

const commitCustomAttributes = (commit, conversationId, customAttributes) =>
  commit(mutationTypes.UPDATE_CONVERSATION_CUSTOM_ATTRIBUTES, {
    conversationId,
    customAttributes,
  });

export default {
  // Grava só as chaves de `changes` (o resto fica como está no servidor);
  // valor vazio apaga a chave.
  mergeCustomAttributes: async ({ commit }, { conversationId, changes }) => {
    const entries = Object.entries(changes);
    const remove = entries
      .filter(([, value]) => isEmptyValue(value))
      .map(([key]) => key);
    const { data } = await TicketsAPI.mergeCustomAttributes({
      conversationId,
      customAttributes: Object.fromEntries(
        entries.filter(([, value]) => !isEmptyValue(value))
      ),
      remove,
    });
    // A mutation mescla com o que já está no store: chave apagada no servidor
    // vai como undefined pra sumir daqui também.
    commitCustomAttributes(commit, conversationId, {
      ...Object.fromEntries(remove.map(key => [key, undefined])),
      ...data.custom_attributes,
    });
  },

  linkTicket: async ({ commit }, { conversationId, relation, ticketId }) => {
    const { data } = await TicketsAPI.link({
      conversationId,
      relation,
      ticketId,
    });
    data.payload.forEach(conversation =>
      commitCustomAttributes(
        commit,
        conversation.id,
        conversation.custom_attributes
      )
    );
  },
};
