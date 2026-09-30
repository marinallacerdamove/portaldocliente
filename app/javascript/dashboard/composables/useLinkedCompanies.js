// PATCH LOCAL (fork) - empresas vinculadas a um contato. No Chatwoot o contato
// tem uma empresa só (company_id), mas o usuário do Portal pode ter várias: o
// Portal manda a lista inteira em custom_attributes.empresas_vinculadas (ids
// de Company desta conta). A empresa principal vem sempre primeiro.
import { computed, watch, toValue } from 'vue';
import { useCompaniesStore } from 'dashboard/stores/companies';

export function useLinkedCompanies(primaryId, linkedIds) {
  const companiesStore = useCompaniesStore();

  const ids = computed(() => {
    const linked = (toValue(linkedIds) || []).map(Number);
    const primary = Number(toValue(primaryId)) || null;
    return [...new Set([primary, ...linked].filter(Boolean))];
  });

  watch(ids, value => companiesStore.fetchMissing(value), { immediate: true });

  const linkedCompanies = computed(() =>
    ids.value.map(id => companiesStore.getRecord(id)).filter(c => c?.id)
  );

  return { linkedCompanies };
}
