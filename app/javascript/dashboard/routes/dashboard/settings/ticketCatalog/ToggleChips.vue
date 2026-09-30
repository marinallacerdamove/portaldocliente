<script setup>
// PATCH LOCAL (fork) - escolha múltipla em botões liga/desliga, no mesmo
// padrão das equipes do MacroForm.vue. Usado nas categorias do serviço e nos
// status da justificativa.
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  // [{ id, name }]
  options: { type: Array, required: true },
  emptyMessage: { type: String, default: '' },
});

const selectedIds = defineModel({ type: Array, default: () => [] });

const toggle = id => {
  selectedIds.value = selectedIds.value.includes(id)
    ? selectedIds.value.filter(selected => selected !== id)
    : [...selectedIds.value, id];
};
</script>

<template>
  <div v-if="options.length" class="flex flex-wrap gap-2">
    <Button
      v-for="option in options"
      :key="option.id"
      :label="option.name"
      :icon="
        selectedIds.includes(option.id) ? 'i-lucide-check' : 'i-lucide-plus'
      "
      xs
      :color="selectedIds.includes(option.id) ? 'blue' : 'slate'"
      :variant="selectedIds.includes(option.id) ? 'faded' : 'outline'"
      @click="toggle(option.id)"
    />
  </div>
  <p v-else class="mb-0 text-xs text-n-slate-10">{{ emptyMessage }}</p>
</template>
