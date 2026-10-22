<script setup>
// Painel lateral do quadro "Licenças utilizadas" da planilha, somado pelo Portal:
// total de licenças ativas em destaque, uma barra por módulo (clicar filtra a
// lista de licenças ao lado) e as combinações (STK_SUP_FIN...).
import { useI18n } from 'vue-i18n';
import UpdateServerModuleChip from './UpdateServerModuleChip.vue';

defineProps({
  summary: { type: Object, default: null },
  selected: { type: String, default: '' },
});
const emit = defineEmits(['select']);

const { t } = useI18n();
const i18nKey = suffix => `COMPANIES.DETAIL.UPDATE_SERVER.SUMMARY.${suffix}`;
</script>

<template>
  <!-- Faixa compacta acima da lista, em qualquer largura. -->
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
      <div class="flex items-baseline gap-2">
        <span class="text-xs text-n-slate-11">{{ t(i18nKey('TOTAL')) }}</span>
        <span class="text-2xl font-semibold tabular-nums text-n-slate-12">
          {{ summary.license_count }}
        </span>
      </div>

      <div class="flex flex-col gap-2">
        <span class="text-xs font-semibold uppercase text-n-slate-10">
          {{ t(i18nKey('PER_MODULE')) }}
        </span>
        <ul class="flex flex-wrap gap-1.5 p-0 m-0 list-none">
          <li v-for="mod in summary.per_module" :key="mod.code">
            <button
              type="button"
              :disabled="!mod.count"
              :aria-pressed="selected === mod.code"
              :title="mod.name"
              class="inline-flex items-center gap-1.5 px-1.5 py-1 text-left rounded-md transition-colors motion-reduce:transition-none disabled:cursor-default focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
              :class="[
                selected === mod.code
                  ? 'bg-n-brand/10 font-medium'
                  : 'enabled:hover:bg-n-alpha-2',
                { 'opacity-50': !mod.count },
              ]"
              @click="emit('select', selected === mod.code ? '' : mod.code)"
            >
              <UpdateServerModuleChip :code="mod.code" :name="mod.name" />
              <span class="text-sm tabular-nums text-n-slate-12">
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
        <ul class="flex flex-wrap gap-x-3 gap-y-1 p-0 m-0 list-none">
          <li
            v-for="item in summary.combinations"
            :key="item.combination"
            class="flex items-center gap-1.5 text-xs"
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
