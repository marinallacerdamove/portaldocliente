<script setup>
// PATCH LOCAL (fork) - estado vazio das listas do Update Server (sem registro
// ainda, ou filtro sem resultado), com o botão de ação no slot.
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  icon: { type: String, required: true },
  title: { type: String, required: true },
  description: { type: String, default: '' },
});
</script>

<template>
  <div
    class="flex flex-col items-center gap-2 px-4 py-8 text-center border border-dashed rounded-lg border-n-weak"
  >
    <span class="p-2 rounded-full bg-n-alpha-2">
      <Icon :icon="icon" class="size-5 text-n-slate-10" />
    </span>
    <p class="my-0 text-sm font-medium text-n-slate-12">{{ title }}</p>
    <p v-if="description" class="my-0 text-xs text-n-slate-11">
      {{ description }}
    </p>
    <div class="mt-1"><slot /></div>
  </div>
</template>
