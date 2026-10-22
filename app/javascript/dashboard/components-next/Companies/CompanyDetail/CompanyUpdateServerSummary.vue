<script setup>
// Quadro "Licenças utilizadas" da planilha, somado pelo Portal: total de
// licenças ativas, quantidade por módulo e as combinações (STK_SUP_FIN...).
import { useI18n } from 'vue-i18n';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';

defineProps({
  summary: { type: Object, default: null },
});

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
      <p class="my-0 text-sm text-n-slate-12">
        <span class="text-n-slate-11">
          {{ t('COMPANIES.DETAIL.UPDATE_SERVER.SUMMARY.TOTAL') }}
        </span>
        <strong class="ltr:ml-2 rtl:mr-2">{{ summary.license_count }}</strong>
      </p>
      <div class="overflow-x-auto">
        <table class="text-sm text-center">
          <thead>
            <tr class="text-xs uppercase text-n-slate-10">
              <th
                v-for="mod in summary.per_module"
                :key="mod.code"
                class="px-3 py-1 font-semibold"
                :title="mod.name"
              >
                {{ mod.code }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr class="text-n-slate-12">
              <td
                v-for="mod in summary.per_module"
                :key="mod.code"
                class="px-3 py-1 tabular-nums"
                :class="{ 'text-n-slate-9': !mod.count }"
              >
                {{ mod.count }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-if="summary.combinations?.length" class="flex flex-col gap-1">
        <span class="text-xs font-semibold uppercase text-n-slate-10">
          {{ t('COMPANIES.DETAIL.UPDATE_SERVER.SUMMARY.COMBINATIONS') }}
        </span>
        <p
          v-for="item in summary.combinations"
          :key="item.combination"
          class="my-0 text-sm text-n-slate-12"
        >
          <span class="font-mono text-xs">{{ item.combination }}</span>
          <strong class="ltr:ml-2 rtl:mr-2">{{ item.count }}</strong>
        </p>
      </div>
    </div>
  </InfoCard>
</template>
