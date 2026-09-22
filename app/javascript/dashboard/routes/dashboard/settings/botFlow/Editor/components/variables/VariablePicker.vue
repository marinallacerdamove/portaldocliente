<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownFloating from 'dashboard/components-next/dropdown-menu/base/DropdownFloating.vue';
import DropdownBody from 'dashboard/components-next/dropdown-menu/base/DropdownBody.vue';
import DropdownSection from 'dashboard/components-next/dropdown-menu/base/DropdownSection.vue';
import VariablePreview from './VariablePreview.vue';

const props = defineProps({
  // ref/função que devolve o elemento âncora (botão ou o próprio campo).
  anchorEl: { type: [Object, Function], default: null },
  entries: { type: Array, default: () => [] },
  recentIds: { type: Array, default: () => [] },
  // Quando informado, entradas fora desses tipos ficam atrás de "Ver todas".
  priorityTypes: { type: Array, default: null },
  initialQuery: { type: String, default: '' },
});

const emit = defineEmits(['select']);
const open = defineModel('open', { type: Boolean, default: false });

const { t } = useI18n();
const vFocus = { mounted: el => el.focus() };

const searchTerm = ref('');
const showAll = ref(false);

watch(open, isOpen => {
  if (!isOpen) return;
  searchTerm.value = props.initialQuery || '';
  showAll.value = !props.priorityTypes;
});

const matchesSearch = entry => {
  if (!searchTerm.value) return true;
  const query = searchTerm.value.toLowerCase();
  return (
    entry.label.toLowerCase().includes(query) ||
    entry.technicalHint.toLowerCase().includes(query) ||
    entry.categoryLabel.toLowerCase().includes(query)
  );
};

const isPriority = entry =>
  !props.priorityTypes || props.priorityTypes.includes(entry.type);

const searchedEntries = computed(() => props.entries.filter(matchesSearch));

const visibleEntries = computed(() =>
  searchedEntries.value.filter(entry => showAll.value || isPriority(entry))
);

const hasHiddenByType = computed(
  () =>
    !showAll.value &&
    !!props.priorityTypes &&
    searchedEntries.value.some(entry => !isPriority(entry))
);

const recentEntries = computed(() =>
  props.recentIds
    .map(id => visibleEntries.value.find(entry => entry.id === id))
    .filter(Boolean)
);

const groupedSections = computed(() => {
  const groups = new Map();
  visibleEntries.value.forEach(entry => {
    if (!groups.has(entry.category)) {
      groups.set(entry.category, {
        key: entry.category,
        title: entry.categoryLabel,
        items: [],
      });
    }
    groups.get(entry.category).items.push(entry);
  });
  return [...groups.values()];
});

const isEmpty = computed(
  () => !recentEntries.value.length && !groupedSections.value.length
);

const select = entry => {
  emit('select', entry);
  open.value = false;
};

const close = () => {
  open.value = false;
};

// anchorEl chega aqui já desembrulhado pelo Vue quando o pai passa
// :anchor-el="algumaRef" direto no template (refs de topo do script setup
// são auto-desembrulhadas em bindings de template) - por isso NÃO tentamos
// ".value" aqui: um <button> tem uma propriedade .value nativa do DOM
// (string vazia por padrão), então tentar ".value" pegava o valor errado.
const triggerFn = () =>
  typeof props.anchorEl === 'function' ? props.anchorEl() : props.anchorEl;
</script>

<template>
  <DropdownFloating v-if="open" :trigger="triggerFn">
    <DropdownBody v-on-click-outside="close" strong class="top-0 w-96">
      <div class="relative">
        <Icon
          icon="i-lucide-search"
          class="absolute size-3.5 left-2.5 top-2.5 text-n-slate-9"
        />
        <input
          v-model="searchTerm"
          v-focus
          type="search"
          class="reset-base w-full h-8 pl-8 pr-2 text-sm rounded-lg bg-n-alpha-1 dark:bg-n-solid-1 text-n-slate-12 border-none focus:outline-none"
          :placeholder="t('BOT_FLOW.EDITOR.VARIABLE_PICKER.SEARCH_PLACEHOLDER')"
        />
      </div>

      <DropdownSection
        v-if="recentEntries.length"
        :title="t('BOT_FLOW.EDITOR.VARIABLES.CATEGORIES.RECENT')"
        height="max-h-28"
      >
        <li v-for="entry in recentEntries" :key="`recent-${entry.id}`">
          <button
            type="button"
            class="flex items-start gap-2 w-full min-w-0 px-2 py-1.5 rounded-lg text-start hover:bg-n-alpha-1 dark:hover:bg-n-alpha-2"
            @click="select(entry)"
          >
            <Icon
              :icon="entry.icon"
              class="size-4 text-n-slate-11 shrink-0 mt-0.5"
            />
            <span class="flex flex-col items-start min-w-0 flex-1">
              <span class="text-sm text-n-slate-12 truncate w-full">
                {{ entry.label }}
              </span>
              <VariablePreview :entry="entry" />
            </span>
          </button>
        </li>
      </DropdownSection>

      <DropdownSection
        v-for="section in groupedSections"
        :key="section.key"
        :title="section.title"
        height="max-h-56"
      >
        <li v-for="entry in section.items" :key="entry.id">
          <button
            type="button"
            class="flex items-start gap-2 w-full min-w-0 px-2 py-1.5 rounded-lg text-start hover:bg-n-alpha-1 dark:hover:bg-n-alpha-2"
            @click="select(entry)"
          >
            <Icon
              :icon="entry.icon"
              class="size-4 text-n-slate-11 shrink-0 mt-0.5"
            />
            <span class="flex flex-col items-start min-w-0 flex-1">
              <span class="text-sm text-n-slate-12 truncate w-full">
                {{ entry.label }}
              </span>
              <VariablePreview :entry="entry" />
            </span>
          </button>
        </li>
      </DropdownSection>

      <button
        v-if="hasHiddenByType"
        type="button"
        class="w-full text-start text-sm text-n-blue-text px-3 py-1.5 hover:bg-n-alpha-1 rounded-lg"
        @click="showAll = true"
      >
        {{ t('BOT_FLOW.EDITOR.VARIABLE_PICKER.SHOW_ALL') }}
      </button>

      <p v-if="isEmpty" class="text-sm text-n-slate-10 px-3 py-2">
        {{ t('BOT_FLOW.EDITOR.VARIABLE_PICKER.EMPTY') }}
      </p>
    </DropdownBody>
  </DropdownFloating>
</template>
