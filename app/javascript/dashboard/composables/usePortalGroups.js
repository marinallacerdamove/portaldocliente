// PATCH LOCAL (fork) - lista de Grupos de clientes (vêm do Portal). Usada na
// tela Grupos e no público das campanhas de WhatsApp.
import { ref } from 'vue';
import PortalGroupsAPI from 'dashboard/api/portalGroups';

export const portalGroupsErrorMessage = error => error?.response?.data?.error;

export function usePortalGroups() {
  const groups = ref([]);
  const isLoading = ref(false);
  const hasError = ref(false);
  const errorMessage = ref('');

  const fetchGroups = async () => {
    isLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';
    try {
      const { data } = await PortalGroupsAPI.get();
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
