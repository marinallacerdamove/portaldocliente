<script setup>
// PATCH LOCAL (fork) - cabeçalho de coluna ordenável com a seta sempre visível
// (esmaecida quando a coluna não é a ordenada). Fixo no topo da tabela.
import { computed } from 'vue';

const props = defineProps({
  label: { type: String, required: true },
  sortKey: { type: String, default: '' },
  activeKey: { type: String, default: null },
  direction: { type: String, default: 'asc' },
  sticky: { type: Boolean, default: false },
});
defineEmits(['sort']);

const isActive = computed(() => props.activeKey === props.sortKey);
const ariaSort = computed(() => {
  if (!isActive.value) return 'none';
  return props.direction === 'asc' ? 'ascending' : 'descending';
});
const icon = computed(() => {
  if (!isActive.value) return 'i-lucide-chevrons-up-down';
  return props.direction === 'asc'
    ? 'i-lucide-chevron-up'
    : 'i-lucide-chevron-down';
});
</script>

<template>
  <th
    scope="col"
    :aria-sort="ariaSort"
    class="sticky top-0 z-10 px-3 py-2 text-xs font-medium text-left whitespace-nowrap bg-n-solid-2 text-n-slate-11"
    :class="{ 'ltr:left-0 rtl:right-0 z-20': sticky }"
  >
    <button
      v-if="sortKey"
      type="button"
      class="inline-flex items-center gap-1 hover:text-n-slate-12"
      :class="{ 'text-n-slate-12': isActive }"
      @click="$emit('sort', sortKey)"
    >
      {{ label }}
      <span class="size-3.5" :class="[icon, { 'opacity-40': !isActive }]" />
    </button>
    <template v-else>{{ label }}</template>
  </th>
</template>
