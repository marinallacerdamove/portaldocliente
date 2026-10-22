<script setup>
// Quadro "Licenças utilizadas" da planilha, somado pelo Portal: total de
// licenças ativas em destaque, quantidade por módulo em pílulas (clicar numa
// pílula filtra a lista de licenças) e as combinações (STK_SUP_FIN...).
import { useI18n } from 'vue-i18n';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import UpdateServerModuleChip from './UpdateServerModuleChip.vue';

defineProps({
  summary: { type: Object, default: null },
  selected: { type: String, default: '' },
});
const emit = defineEmits(['select']);

const { t } = useI18n();
</script>

<template>
  <InfoCard
    :title="t('COMPANIES.DETAIL.UPDATE_SERVER.SUMMARY.TITLE')"
    icon="i-lucide-sigma"
  >
    <template #actions>
      <span />
    </template>
    <p
      v-if="!summary || !summary.license_count"
      class="my-0 text-sm text-n-slate-11"
    >
      {{ t('COMPANIES.DETAIL.UPDATE_SERVER.SUMMARY.EMPTY') }}
    </p>
    <div v-else class="flex flex-col gap-4">
      <div class="flex items-baseline gap-2">
        <span class="text-3xl font-semibold tabular-nums text-n-slate-12">
          {{ summary.license_count }}
        </span>
        <span class="text-sm text-n-slate-11">
          {{ t('COMPANIES.DETAIL.UPDATE_SERVER.SUMMARY.TOTAL') }}
        </span>
      </div>

      <div class="flex flex-col gap-2">
        <span class="text-xs font-semibold uppercase text-n-slate-10">
          {{ t('COMPANIES.DETAIL.UPDATE_SERVER.SUMMARY.PER_MODULE') }}
        </span>
        <ul class="flex flex-wrap gap-2 p-0 m-0 list-none">
          <li v-for="mod in summary.per_module" :key="mod.code">
            <button
              type="button"
              :disabled="!mod.count"
              :aria-pressed="selected === mod.code"
              :title="mod.name"
              class="flex items-center gap-2 px-2.5 py-1.5 border rounded-lg transition-colors disabled:cursor-default"
              :class="[
                selected === mod.code
                  ? 'border-n-brand bg-n-brand/10'
                  : 'border-n-weak bg-n-solid-1 enabled:hover:bg-n-alpha-1',
                { 'opacity-50': !mod.count },
              ]"
              @click="emit('select', selected === mod.code ? '' : mod.code)"
            >
              <UpdateServerModuleChip :code="mod.code" :name="mod.name" />
              <span class="text-sm font-medium tabular-nums text-n-slate-12">
                {{ mod.count }}
              </span>
            </button>
          </li>
        </ul>
        <p class="my-0 text-xs text-n-slate-10">
          {{ t('COMPANIES.DETAIL.UPDATE_SERVER.SUMMARY.FILTER_HINT') }}
        </p>
      </div>

      <div v-if="summary.combinations?.length" class="flex flex-col gap-2">
        <span class="text-xs font-semibold uppercase text-n-slate-10">
          {{ t('COMPANIES.DETAIL.UPDATE_SERVER.SUMMARY.COMBINATIONS') }}
        </span>
        <ul class="flex flex-wrap gap-2 p-0 m-0 list-none">
          <li
            v-for="item in summary.combinations"
            :key="item.combination"
            class="flex items-center gap-2 px-2 py-1 text-xs rounded-md bg-n-alpha-2"
          >
            <span class="font-mono text-n-slate-12">{{
              item.combination
            }}</span>
            <span class="font-medium tabular-nums text-n-slate-11">
              {{ `×${item.count}` }}
            </span>
          </li>
        </ul>
      </div>
    </div>
  </InfoCard>
</template>
