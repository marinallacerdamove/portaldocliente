<script setup>
// ARQUIVO DO FORK - Select com rótulo em cima, mesmo padrão visual do
// Input.vue (span.text-heading-3). O Select.vue do upstream fica intacto (tem
// telas do upstream que estilizam a raiz dele com [&>select]); aqui só se
// embrulha ele num <label>, que já liga o rótulo ao select sem precisar de id.
// Tudo que não é daqui (options, placeholder, disabled, error...) vai direto
// pro Select; class/style ficam na raiz, que ocupa a largura da coluna.
import { computed, useAttrs } from 'vue';
import Select from 'dashboard/components-next/select/Select.vue';

defineProps({
  label: { type: String, default: '' },
});

defineOptions({ inheritAttrs: false });

const modelValue = defineModel({
  type: [String, Number, Boolean],
  default: '',
});

const attrs = useAttrs();
const rootAttrs = computed(() => ({
  class: attrs.class,
  style: attrs.style,
}));
const selectAttrs = computed(() => {
  const { class: _class, style: _style, ...rest } = attrs;
  return rest;
});
</script>

<template>
  <label class="flex flex-col min-w-0 gap-1" v-bind="rootAttrs">
    <span v-if="label" class="mb-0.5 text-heading-3 text-n-slate-12">
      {{ label }}
    </span>
    <!-- A raiz do Select é w-fit: !w-full faz ele ocupar a coluna inteira -->
    <Select v-model="modelValue" v-bind="selectAttrs" class="!w-full" />
  </label>
</template>
