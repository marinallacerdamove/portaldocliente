import { ref } from 'vue';

const MAX_RECENT = 6;

// Guarda as últimas variáveis inseridas nesse fluxo, só nesse navegador (não
// é salvo no fluxo em si) - ajuda quem monta o bot a reaproveitar rápido as
// informações que já usou nos blocos anteriores, sem precisar buscar de novo.
export function useRecentVariables(botFlowId) {
  const storageKey = `cw-bot-flow-recent-variables-${botFlowId || 'new'}`;

  const readStored = () => {
    try {
      const raw = localStorage.getItem(storageKey);
      return raw ? JSON.parse(raw) : [];
    } catch {
      return [];
    }
  };

  const recentIds = ref(readStored());

  const persist = () => {
    try {
      localStorage.setItem(storageKey, JSON.stringify(recentIds.value));
    } catch {
      // Sem espaço/privado - a lista de recentes é só conveniência.
    }
  };

  const recordUsage = id => {
    if (!id) return;
    recentIds.value = [
      id,
      ...recentIds.value.filter(existingId => existingId !== id),
    ].slice(0, MAX_RECENT);
    persist();
  };

  return { recentIds, recordUsage };
}
