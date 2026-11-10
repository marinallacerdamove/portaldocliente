<script setup>
// PATCH LOCAL (fork) - busca de quem adicionar a um grupo (empresa ou contato
// avulso): digita, aparecem até 8 sugestões (sem quem já está no grupo) e o
// clique avisa (add). Não grava nada.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { picoSearch } from '@chatwoot/pico-search';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  // [{ id, primary, secondary }]; a busca olha os dois textos
  candidates: { type: Array, default: () => [] },
  // ids que já estão no grupo (não aparecem como sugestão)
  excludedIds: { type: Array, default: () => [] },
  placeholder: { type: String, default: '' },
  isLoading: { type: Boolean, default: false },
  error: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['add', 'retry']);

const MAX_SUGGESTIONS = 8;

const { t } = useI18n();
const query = ref('');
const searchTerm = computed(() => query.value.trim());

const suggestions = computed(() => {
  if (!searchTerm.value) return [];
  const taken = new Set(props.excludedIds);
  const free = props.candidates.filter(candidate => !taken.has(candidate.id));
  return picoSearch(free, searchTerm.value, ['primary', 'secondary']).slice(
    0,
    MAX_SUGGESTIONS
  );
});

const add = candidate => {
  emit('add', candidate.id);
  query.value = '';
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <Input
      v-model="query"
      type="search"
      size="sm"
      :placeholder="placeholder"
      :disabled="disabled"
    />
    <p v-if="isLoading" class="mb-0 text-xs text-n-slate-11">
      {{ t('PORTAL_GROUPS.SEARCH.LOADING') }}
    </p>
    <div v-else-if="error" class="flex flex-col items-start gap-2">
      <p class="mb-0 text-xs text-n-ruby-11">{{ error }}</p>
      <Button
        :label="t('PORTAL_GROUPS.RETRY')"
        variant="faded"
        color="slate"
        size="xs"
        type="button"
        @click="emit('retry')"
      />
    </div>
    <ul
      v-else-if="suggestions.length"
      class="flex flex-col pl-0 mb-0 list-none border divide-y rounded-lg border-n-weak divide-n-weak"
    >
      <li v-for="candidate in suggestions" :key="candidate.id">
        <button
          type="button"
          class="flex items-center justify-between w-full gap-3 px-3 py-2 text-start hover:bg-n-alpha-2 disabled:opacity-50"
          :disabled="disabled"
          @click="add(candidate)"
        >
          <span class="flex flex-col min-w-0">
            <span class="text-sm font-medium truncate text-n-slate-12">
              {{ candidate.primary }}
            </span>
            <span
              v-if="candidate.secondary"
              class="text-xs truncate text-n-slate-11"
            >
              {{ candidate.secondary }}
            </span>
          </span>
          <span class="flex items-center gap-1 text-xs shrink-0 text-n-blue-11">
            <span class="i-lucide-plus size-3.5" />
            {{ t('PORTAL_GROUPS.SEARCH.ADD') }}
          </span>
        </button>
      </li>
    </ul>
    <p v-else-if="searchTerm" class="mb-0 text-xs text-n-slate-11">
      {{ t('PORTAL_GROUPS.SEARCH.NO_MATCH') }}
    </p>
  </div>
</template>
