// PATCH LOCAL (fork) - perguntar ao Assistente e avaliar a resposta. Usado pela
// aba "Perguntar" e pelo painel do Assistente no editor de resposta.
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import PortalAssistantAPI from 'dashboard/api/portalAssistant';
import { usePortalAssistant } from 'dashboard/composables/usePortalAssistant';

export const MAX_QUESTION_LENGTH = 2000;
export const RATINGS = { UP: 'up', DOWN: 'down' };

export function usePortalAssistantAsk() {
  const { t } = useI18n();
  const { errorMessage } = usePortalAssistant();
  const isAsking = ref(false);

  // Resposta do Portal ({ id, question, answer, answered, sources, rating })
  // ou null se falhou (o erro já foi mostrado).
  const ask = async question => {
    const text = question.trim();
    if (!text || isAsking.value) return null;

    isAsking.value = true;
    try {
      const { data } = await PortalAssistantAPI.ask(text);
      return data;
    } catch (error) {
      useAlert(errorMessage(error, t('PORTAL_ASSISTANT.ASK.ERROR')));
      return null;
    } finally {
      isAsking.value = false;
    }
  };

  // Clicar de novo na mesma avaliação desfaz.
  const rate = async (item, rating) => {
    const next = item.rating === rating ? null : rating;
    try {
      const { data } = await PortalAssistantAPI.rate(item.id, next);
      item.rating = data.rating;
    } catch {
      useAlert(t('PORTAL_ASSISTANT.ASK.RATE_ERROR'));
    }
  };

  return { isAsking, ask, rate };
}
