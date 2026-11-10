<script setup>
// PATCH LOCAL (fork) - linha base da ficha do grupo. Uma grade fixa de colunas
// (caixa, avatar, nome, informação, situação, seta) usada por empresa, contato
// da empresa e contato avulso, pra tudo ficar alinhado na mesma coluna.
defineProps({
  // linha clicável (hover e cursor)
  interactive: { type: Boolean, default: false },
  // contato aberto dentro de uma empresa (fundo levemente diferente)
  nested: { type: Boolean, default: false },
});
</script>

<template>
  <div
    class="grid grid-cols-[1rem_2rem_minmax(0,1fr)_11rem_10rem_1rem] items-center gap-x-4 px-4 py-2.5 min-h-14"
    :class="{
      'cursor-pointer hover:bg-n-alpha-1': interactive,
      'bg-n-alpha-1': nested,
    }"
  >
    <div class="flex items-center justify-center"><slot name="check" /></div>
    <div class="flex items-center justify-center"><slot name="avatar" /></div>
    <div class="flex flex-col min-w-0 gap-0.5"><slot /></div>
    <div class="text-sm truncate text-n-slate-11"><slot name="info" /></div>
    <div class="flex items-center"><slot name="status" /></div>
    <div class="flex items-center justify-center text-n-slate-10">
      <slot name="end" />
    </div>
  </div>
</template>
