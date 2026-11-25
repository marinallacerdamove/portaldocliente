// PATCH LOCAL (fork) - perguntar ao Assistente e avaliar a resposta. Usado pela
// aba "Perguntar" e pelo painel do Assistente no editor de resposta.
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import PortalAssistantAPI from 'dashboard/api/portalAssistant';
import { usePortalAssistant } from 'dashboard/composables/usePortalAssistant';

export const MAX_QUESTION_LENGTH = 2000;
export const RATINGS = { UP: 'up', DOWN: 'down' };
// O Portal responde em segundo plano (B37): a pergunta volta "respondendo"
// e a tela consulta de tempos em tempos, até o limite.
export const POLL_INTERVAL_MS = 1500;
export const MAX_WAIT_MS = 120000;

const wait = ms =>
  new Promise(resolve => {
    setTimeout(resolve, ms);
  });

// Consulta até a pergunta sair de "respondendo"; null se passou do limite.
const waitForAnswer = async question => {
  let current = question;
  for (
    let waited = 0;
    current.pending && waited < MAX_WAIT_MS;
    waited += POLL_INTERVAL_MS
  ) {
    // eslint-disable-next-line no-await-in-loop
    await wait(POLL_INTERVAL_MS);
    // eslint-disable-next-line no-await-in-loop
    ({ data: current } = await PortalAssistantAPI.getQuestion(question.id));
  }
  return current.pending ? null : current;
};

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
      const answer = await waitForAnswer(data);
      if (!answer) {
        useAlert(t('PORTAL_ASSISTANT.ASK.TIMEOUT'));
        return null;
      }
      if (answer.failed) {
        useAlert(answer.error_message || t('PORTAL_ASSISTANT.ASK.ERROR'));
        return null;
      }
      return answer;
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
