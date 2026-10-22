<script setup>
// PATCH LOCAL (fork) - chip de módulo do Albatross. A cor sai do código do
// módulo (mesma cor sempre, em qualquer tela), numa paleta curta de pares
// fundo/texto do design do fork, que mantém o contraste no tema claro e escuro.
import { computed } from 'vue';

const props = defineProps({
  code: { type: String, required: true },
  name: { type: String, default: '' },
  inactive: { type: Boolean, default: false },
});

// Classes por extenso: o Tailwind só enxerga o que está escrito no arquivo.
const PALETTE = [
  'bg-n-blue-3 text-n-blue-11',
  'bg-n-teal-3 text-n-teal-11',
  'bg-n-amber-3 text-n-amber-11',
  'bg-n-iris-3 text-n-iris-11',
  'bg-n-ruby-3 text-n-ruby-11',
  'bg-n-alpha-2 text-n-slate-12',
];

const paletteIndex = code =>
  [...code].reduce((sum, char) => sum + char.charCodeAt(0), 0) % PALETTE.length;

const colorClass = computed(() => PALETTE[paletteIndex(props.code)]);
</script>

<template>
  <span
    class="inline-flex items-center px-1.5 py-0.5 text-xs font-medium rounded-md"
    :class="[
      colorClass,
      { 'opacity-60 outline-dashed outline-1 outline-n-weak': inactive },
    ]"
    :title="name || code"
  >
    {{ code }}
  </span>
</template>
