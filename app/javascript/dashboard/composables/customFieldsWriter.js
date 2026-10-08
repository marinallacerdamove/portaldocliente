// PATCH LOCAL (fork) - grava campos_adicionais de uma conversa sem perder
// marcações feitas em sequência (checklist, múltipla escolha). A tela muda na
// hora (otimista) e só um PATCH por conversa fica em andamento; o que for
// marcado enquanto ele roda vai junto no próximo, com o estado mais novo.
import mutationTypes from 'dashboard/store/mutation-types';
import { CUSTOM_FIELDS_ATTRIBUTE_KEY } from 'dashboard/helper/ticketFieldRules';

const writers = new Map();

const showValues = (store, conversationId, values) =>
  store.commit(mutationTypes.UPDATE_CONVERSATION_CUSTOM_ATTRIBUTES, {
    conversationId,
    customAttributes: { [CUSTOM_FIELDS_ATTRIBUTE_KEY]: values },
  });

const flush = async (store, conversationId, writer) => {
  try {
    do {
      writer.dirty = false;
      // eslint-disable-next-line no-await-in-loop
      await store.dispatch('mergeCustomAttributes', {
        conversationId,
        changes: { [CUSTOM_FIELDS_ATTRIBUTE_KEY]: writer.values },
      });
      // A resposta traz o estado do servidor; marcação feita enquanto ela vinha
      // volta pra tela.
      if (writer.dirty) showValues(store, conversationId, writer.values);
    } while (writer.dirty);
  } catch (error) {
    await store.dispatch('getConversation', conversationId);
    throw error;
  } finally {
    writers.delete(conversationId);
  }
};

// Devolve a promise da gravação em andamento (a mesma pra quem chegou durante ela).
export const saveCustomFields = (store, conversationId, values) => {
  showValues(store, conversationId, values);
  const writer = writers.get(conversationId);
  if (writer) {
    writer.values = values;
    writer.dirty = true;
    return writer.promise;
  }
  const created = { values, dirty: false };
  created.promise = flush(store, conversationId, created);
  writers.set(conversationId, created);
  return created.promise;
};
