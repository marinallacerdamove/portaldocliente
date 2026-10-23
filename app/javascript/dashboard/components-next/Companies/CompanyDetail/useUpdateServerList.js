// PATCH LOCAL (fork) - estado de lista das tabelas do Updater Server: busca,
// filtro de status e ordenação, iguais pra Bases e Licenças.
import { computed, ref } from 'vue';
import {
  matchesSearch,
  matchesStatus,
  sortItems,
  statusCounts,
} from './updateServerHelpers';

export const useUpdateServerList = (
  getItems,
  { searchKeys, sortKey = null }
) => {
  const search = ref('');
  const status = ref('all');
  const sortBy = ref(sortKey);
  const sortDirection = ref('asc');

  const counts = computed(() => statusCounts(getItems()));

  const visible = computed(() =>
    sortItems(
      getItems().filter(
        item =>
          matchesStatus(item, status.value) &&
          matchesSearch(item, search.value, searchKeys)
      ),
      sortBy.value,
      sortDirection.value
    )
  );

  const hasFilters = computed(
    () => status.value !== 'all' || search.value.trim() !== ''
  );

  const toggleSort = key => {
    if (sortBy.value === key) {
      sortDirection.value = sortDirection.value === 'asc' ? 'desc' : 'asc';
    } else {
      sortBy.value = key;
      sortDirection.value = 'asc';
    }
  };

  const clearFilters = () => {
    search.value = '';
    status.value = 'all';
  };

  return {
    search,
    status,
    sortBy,
    sortDirection,
    counts,
    visible,
    hasFilters,
    toggleSort,
    clearFilters,
  };
};
