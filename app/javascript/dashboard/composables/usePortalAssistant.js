// PATCH LOCAL (fork) - Assistente (IA com base na wiki): contas habilitadas
// vêm de PORTAL_ASSISTANT_ACCOUNT_IDS (window.chatwootConfig).
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';

export function usePortalAssistant() {
  const { locale } = useI18n();
  const accountId = useMapGetter('getCurrentAccountId');

  const isEnabled = computed(() =>
    (window.chatwootConfig?.portalAssistantAccountIds || []).includes(
      Number(accountId.value)
    )
  );

  // Locale do Chatwoot vem como "pt_BR"; o Intl só aceita "pt-BR".
  const formatDate = iso =>
    new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
      dateStyle: 'short',
      timeStyle: 'short',
    }).format(new Date(iso));

  const errorMessage = (error, fallback) =>
    error?.response?.data?.error || fallback;

  return { isEnabled, formatDate, errorMessage };
}
