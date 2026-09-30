<script setup>
// PATCH LOCAL (fork) - seletor compacto do cabeçalho da conversa, no mesmo
// visual do botão Resolver (botão pequeno + menu).
import { computed } from 'vue';
import { useToggle } from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';
import ButtonGroup from 'dashboard/components-next/buttonGroup/ButtonGroup.vue';
import WootDropdownItem from 'shared/components/ui/dropdown/DropdownItem.vue';
import WootDropdownMenu from 'shared/components/ui/dropdown/DropdownMenu.vue';

const props = defineProps({
  options: { type: Array, required: true },
  selectedId: { type: String, default: '' },
  placeholder: { type: String, required: true },
  title: { type: String, default: '' },
  highlight: { type: Boolean, default: false },
});

const emit = defineEmits(['select']);

const [isOpen, toggleOpen] = useToggle(false);
const close = () => toggleOpen(false);

const selectedName = computed(
  () =>
    props.options.find(option => option.id === props.selectedId)?.name ||
    props.selectedId
);

const onSelect = option => {
  close();
  emit('select', option);
};
</script>

<template>
  <div class="relative flex items-center">
    <ButtonGroup
      class="flex-shrink-0 rounded-lg shadow outline-1 outline"
      :class="highlight ? 'outline-n-amber-9' : 'outline-n-container'"
      no-animation
    >
      <Button
        :label="selectedName || placeholder"
        :title="title"
        size="sm"
        color="slate"
        no-animation
        trailing-icon
        icon="i-lucide-chevron-down"
        class="max-w-[11rem] !outline-0"
        @click="toggleOpen()"
      />
    </ButtonGroup>
    <div
      v-if="isOpen"
      v-on-clickaway="close"
      class="absolute block z-10 p-2 mt-0.5 overflow-y-auto border rounded-lg shadow-lg top-full end-0 box-content w-fit min-w-[9.75rem] max-w-[16rem] max-h-[18rem] border-n-strong bg-n-alpha-3 backdrop-blur-[100px] [&_ul>li]:mb-0"
    >
      <WootDropdownMenu class="mb-0">
        <WootDropdownItem v-for="option in options" :key="option.id">
          <Button
            :label="option.name"
            :icon="option.id === selectedId ? 'i-lucide-check' : ''"
            ghost
            slate
            sm
            start
            class="w-full"
            @click="onSelect(option)"
          />
        </WootDropdownItem>
      </WootDropdownMenu>
    </div>
  </div>
</template>
