import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

// PATCH LOCAL (fork) - grava vários custom attributes da conversa num update
// só; valor vazio remove a chave.
export function useSaveConversationAttributes() {
  const store = useStore();
  const { t } = useI18n();

  return async (conversation, changes) => {
    const updatedAttributes = { ...(conversation.custom_attributes || {}) };
    Object.entries(changes).forEach(([key, value]) => {
      if (value) updatedAttributes[key] = value;
      else delete updatedAttributes[key];
    });
    try {
      await store.dispatch('updateCustomAttributes', {
        conversationId: conversation.id,
        customAttributes: updatedAttributes,
      });
      useAlert(t('CUSTOM_ATTRIBUTES.FORM.UPDATE.SUCCESS'));
      return true;
    } catch {
      useAlert(t('CUSTOM_ATTRIBUTES.FORM.UPDATE.ERROR'));
      return false;
    }
  };
}
