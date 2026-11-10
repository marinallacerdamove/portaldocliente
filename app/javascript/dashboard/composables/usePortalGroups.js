// PATCH LOCAL (fork) - lista de Grupos de clientes (vêm do Portal). Usada na
// tela Grupos (Configurações), com os inativos, e no público das campanhas de
// WhatsApp, só com os ativos.
import { ref } from 'vue';
import PortalGroupsAPI from 'dashboard/api/portalGroups';

// Mensagens de erro do Portal: 422 traz `errors` (lista), os demais `error`.
export const portalGroupsErrorMessage = error => {
  const data = error?.response?.data;
  return data?.errors?.join(' ') || data?.error;
};

export function usePortalGroups() {
  const groups = ref([]);
  const isLoading = ref(false);
  const hasError = ref(false);
  const errorMessage = ref('');

  const fetchGroups = async ({ all = false } = {}) => {
    isLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';
    try {
      const { data } = await PortalGroupsAPI.get({ all });
      groups.value = data.data;
    } catch (error) {
      groups.value = [];
      hasError.value = true;
      errorMessage.value = portalGroupsErrorMessage(error) || '';
    } finally {
      isLoading.value = false;
    }
  };

  return { groups, isLoading, hasError, errorMessage, fetchGroups };
}
