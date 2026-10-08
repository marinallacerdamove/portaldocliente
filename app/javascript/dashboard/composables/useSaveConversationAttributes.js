import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

// PATCH LOCAL (fork) - grava vários custom attributes da conversa num update
// só, mandando só as chaves alteradas (merge no servidor); valor vazio remove
// a chave.
export function useSaveConversationAttributes() {
  const store = useStore();
  const { t } = useI18n();

  return async (conversation, changes) => {
    try {
      await store.dispatch('mergeCustomAttributes', {
        conversationId: conversation.id,
        changes,
      });
      useAlert(t('CUSTOM_ATTRIBUTES.FORM.UPDATE.SUCCESS'));
      return true;
    } catch {
      useAlert(t('CUSTOM_ATTRIBUTES.FORM.UPDATE.ERROR'));
      return false;
    }
  };
}
