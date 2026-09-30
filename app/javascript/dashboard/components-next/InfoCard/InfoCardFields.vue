<script setup>
// PATCH LOCAL (fork) - grade de leitura das fichas (empresa, contato): rótulo em cima,
// valor embaixo, duas colunas (mesmo padrão das fichas do Portal).
// item: { key, label, value, kind?: 'chips' | 'links' | 'mono' | 'multiline', full? }
// kind 'links': value = [{ id, label, to }] (to = rota do vue-router).
defineProps({
  items: { type: Array, required: true },
});

const EMPTY_VALUE = '—';
const isEmpty = value =>
  Array.isArray(value) ? value.length === 0 : !String(value ?? '').trim();
</script>

<template>
  <dl class="grid gap-x-6 gap-y-4 sm:grid-cols-2 my-0">
    <div
      v-for="item in items"
      :key="item.key"
      class="flex flex-col min-w-0 gap-1"
      :class="{ 'sm:col-span-2': item.full }"
    >
      <dt class="text-xs font-medium text-n-slate-11">{{ item.label }}</dt>
      <dd class="my-0 text-sm break-words text-n-slate-12">
        <span v-if="isEmpty(item.value)" class="text-n-slate-10">
          {{ EMPTY_VALUE }}
        </span>
        <span v-else-if="item.kind === 'chips'" class="flex flex-wrap gap-1.5">
          <span
            v-for="chip in item.value"
            :key="chip"
            class="px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-12"
          >
            {{ chip }}
          </span>
        </span>
        <span v-else-if="item.kind === 'links'" class="flex flex-wrap gap-1.5">
          <router-link
            v-for="link in item.value"
            :key="link.id"
            :to="link.to"
            class="px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-blue-11 hover:underline"
          >
            {{ link.label }}
          </router-link>
        </span>
        <span v-else-if="item.kind === 'mono'" class="font-mono">
          {{ item.value }}
        </span>
        <span v-else-if="item.kind === 'multiline'" class="whitespace-pre-line">
          {{ item.value }}
        </span>
        <template v-else>{{ item.value }}</template>
      </dd>
    </div>
  </dl>
</template>
