import { ref } from 'vue';

// Estado compartilhado (singleton do módulo) entre o Message.vue de cada
// bolha e o MessagesView.vue que decide o que renderizar no lugar do
// ReplyBox - os dois importam este arquivo, não há relação de
// componente-pai/filho direta entre eles.
const editingMessage = ref(null);

export function useMessageEditing() {
  const startEditing = message => {
    editingMessage.value = message;
  };

  const stopEditing = () => {
    editingMessage.value = null;
  };

  return { editingMessage, startEditing, stopEditing };
}
