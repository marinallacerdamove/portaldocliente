<script setup>
// PATCH LOCAL (fork) - cabeçalho de coluna ordenável com a seta sempre visível
// (esmaecida quando a coluna não é a ordenada). Fixo no topo da tabela.
import { computed } from 'vue';

const props = defineProps({
  label: { type: String, required: true },
  title: { type: String, default: '' },
  sortKey: { type: String, default: '' },
  activeKey: { type: String, default: null },
  direction: { type: String, default: 'asc' },
  sticky: { type: Boolean, default: false },
  numeric: { type: Boolean, default: false },
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
    class="sticky top-0 z-10 py-2 text-xs font-medium whitespace-nowrap bg-n-solid-2 text-n-slate-11"
    :class="[
      numeric ? 'w-20 px-4 text-center' : 'px-3 text-left',
      { 'ltr:left-0 rtl:right-0 z-20': sticky },
    ]"
  >
    <button
      v-if="sortKey"
      type="button"
      :title="title || undefined"
      :aria-label="title || undefined"
      class="relative inline-flex items-center gap-1 hover:text-n-slate-12"
      :class="{ 'text-n-slate-12': isActive }"
      @click="$emit('sort', sortKey)"
    >
      {{ label }}
      <span
        class="size-3.5"
        :class="[
          icon,
          { 'opacity-40': !isActive },
          numeric ? 'absolute -end-4 top-1/2 -translate-y-1/2' : '',
        ]"
      />
    </button>
    <template v-else>{{ label }}</template>
  </th>
</template>
