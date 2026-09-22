import { ref, computed, watch } from 'vue';

// Estado local (não Vuex): seleção de mensagens dentro de UMA conversa, pra
// criar um ticket interno a partir de trechos dela. Diferente do módulo
// bulkActions (que seleciona CONVERSAS e é global/persiste entre navegações
// de propósito) - aqui a seleção precisa morrer ao trocar de conversa, então
// vive só na instância do componente que usa este composable.
export function useMessageSelection(conversationId) {
  const isSelectionModeActive = ref(false);
  const selectedMessageIds = ref([]);

  const clearSelection = () => {
    selectedMessageIds.value = [];
  };

  const toggleSelectionMode = () => {
    isSelectionModeActive.value = !isSelectionModeActive.value;
    clearSelection();
  };

  const isMessageSelected = id => selectedMessageIds.value.includes(id);

  const toggleMessageSelection = id => {
    if (isMessageSelected(id)) {
      selectedMessageIds.value = selectedMessageIds.value.filter(
        selectedId => selectedId !== id
      );
    } else {
      selectedMessageIds.value = [...selectedMessageIds.value, id];
    }
  };

  const selectedCount = computed(() => selectedMessageIds.value.length);

  if (conversationId) {
    watch(conversationId, () => {
      isSelectionModeActive.value = false;
      clearSelection();
    });
  }

  return {
    isSelectionModeActive,
    selectedMessageIds,
    selectedCount,
    toggleSelectionMode,
    isMessageSelected,
    toggleMessageSelection,
    clearSelection,
  };
}
