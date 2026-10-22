<script setup>
// Painel lateral do quadro "Licenças utilizadas" da planilha, somado pelo Portal:
// total de licenças ativas em destaque, uma barra por módulo (clicar filtra a
// lista de licenças ao lado) e as combinações (STK_SUP_FIN...).
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import UpdateServerModuleChip from './UpdateServerModuleChip.vue';

const props = defineProps({
  summary: { type: Object, default: null },
  selected: { type: String, default: '' },
});
const emit = defineEmits(['select']);

const { t } = useI18n();
const i18nKey = suffix => `COMPANIES.DETAIL.UPDATE_SERVER.SUMMARY.${suffix}`;

const maxCount = computed(() =>
  Math.max(1, ...(props.summary?.per_module ?? []).map(mod => mod.count))
);
const barWidth = count => `${Math.round((count / maxCount.value) * 100)}%`;
</script>

<template>
  <!-- Faixa compacta acima da lista; coluna lateral estreita só em tela larga (2xl). -->
  <aside
    class="flex flex-col gap-3 p-3 border rounded-lg border-n-weak bg-n-alpha-1 h-fit"
  >
    <p
      v-if="!summary || !summary.license_count"
      class="my-0 text-sm text-n-slate-11"
    >
      {{ t(i18nKey('EMPTY')) }}
    </p>
    <template v-else>
      <div class="flex items-baseline gap-2 2xl:flex-col 2xl:gap-1">
        <span class="text-xs text-n-slate-11">{{ t(i18nKey('TOTAL')) }}</span>
        <span class="text-2xl font-semibold tabular-nums text-n-slate-12">
          {{ summary.license_count }}
        </span>
      </div>

      <div class="flex flex-col gap-2">
        <span class="text-xs font-semibold uppercase text-n-slate-10">
          {{ t(i18nKey('PER_MODULE')) }}
        </span>
        <ul
          class="flex flex-wrap gap-1.5 p-0 m-0 list-none 2xl:flex-col 2xl:gap-1"
        >
          <li
            v-for="mod in summary.per_module"
            :key="mod.code"
            class="2xl:w-full"
          >
            <button
              type="button"
              :disabled="!mod.count"
              :aria-pressed="selected === mod.code"
              :title="mod.name"
              class="inline-flex items-center gap-1.5 px-1.5 py-1 text-left rounded-md transition-colors motion-reduce:transition-none disabled:cursor-default focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand 2xl:grid 2xl:w-full 2xl:gap-2 2xl:grid-cols-[3.25rem_minmax(0,1fr)_1.75rem]"
              :class="[
                selected === mod.code
                  ? 'bg-n-brand/10 font-medium'
                  : 'enabled:hover:bg-n-alpha-2',
                { 'opacity-50': !mod.count },
              ]"
              @click="emit('select', selected === mod.code ? '' : mod.code)"
            >
              <UpdateServerModuleChip :code="mod.code" :name="mod.name" />
              <span
                class="hidden h-2 overflow-hidden rounded-full 2xl:block bg-n-alpha-2"
              >
                <span
                  class="block h-full transition-[width] duration-200 rounded-full motion-reduce:transition-none"
                  :class="selected === mod.code ? 'bg-n-teal-9' : 'bg-n-brand'"
                  :style="{ width: barWidth(mod.count) }"
                />
              </span>
              <span
                class="text-sm tabular-nums 2xl:ltr:text-right 2xl:rtl:text-left text-n-slate-12"
              >
                {{ mod.count }}
              </span>
            </button>
          </li>
        </ul>
        <p class="my-0 text-xs text-n-slate-10">
          {{ t(i18nKey('FILTER_HINT')) }}
        </p>
      </div>

      <div v-if="summary.combinations?.length" class="flex flex-col gap-1.5">
        <span class="text-xs font-semibold uppercase text-n-slate-10">
          {{ t(i18nKey('COMBINATIONS')) }}
        </span>
        <ul
          class="flex flex-wrap gap-x-3 gap-y-1 p-0 m-0 list-none 2xl:flex-col"
        >
          <li
            v-for="item in summary.combinations"
            :key="item.combination"
            class="flex items-center gap-1.5 text-xs 2xl:justify-between"
          >
            <span class="font-mono truncate text-n-slate-11">{{
              item.combination
            }}</span>
            <span class="font-medium tabular-nums text-n-slate-12">
              {{ `×${item.count}` }}
            </span>
          </li>
        </ul>
      </div>
    </template>
  </aside>
</template>
