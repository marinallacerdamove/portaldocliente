<script setup>
// PATCH LOCAL (fork) - barra única das listas do Updater Server: busca à
// esquerda, filtro de status em controle segmentado e as ações à direita
// (slot). Os contadores ficam discretos embaixo.
import { useId } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import { STATUS_FILTERS } from './updateServerHelpers';

defineProps({
  searchPlaceholder: { type: String, default: '' },
  counts: { type: Object, required: true },
  shown: { type: Number, default: 0 },
  total: { type: Number, default: 0 },
});

const search = defineModel('search', { type: String, default: '' });
const status = defineModel('status', { type: String, default: 'all' });

const { t } = useI18n();
const searchId = `update-server-search-${useId()}`;
</script>

<template>
  <div class="flex flex-col gap-2 mb-3">
    <div class="flex flex-wrap items-center gap-2">
      <div class="flex-1 min-w-[16rem] max-w-[28rem]">
        <label :for="searchId" class="sr-only">{{ searchPlaceholder }}</label>
        <Input
          :id="searchId"
          v-model="search"
          size="sm"
          :placeholder="searchPlaceholder"
          custom-input-class="h-8 !pt-1 !pb-1"
        />
      </div>
      <div
        role="group"
        :aria-label="t('COMPANIES.DETAIL.UPDATE_SERVER.FILTERS.LABEL')"
        class="inline-flex p-0.5 rounded-lg bg-n-alpha-2"
      >
        <button
          v-for="option in STATUS_FILTERS"
          :key="option"
          type="button"
          :aria-pressed="status === option"
          class="px-2.5 py-1 text-xs rounded-md transition-colors"
          :class="
            status === option
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm font-medium'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="status = option"
        >
          {{
            t(`COMPANIES.DETAIL.UPDATE_SERVER.FILTERS.${option.toUpperCase()}`)
          }}
        </button>
      </div>
      <slot name="actions" />
    </div>
    <p class="my-0 text-xs text-n-slate-10">
      {{
        t('COMPANIES.DETAIL.UPDATE_SERVER.COUNTS', {
          active: counts.active,
          inactive: counts.inactive,
        })
      }}
      <template v-if="shown !== total">
        {{
          ` · ${t('COMPANIES.DETAIL.UPDATE_SERVER.SHOWING', { shown, total })}`
        }}
      </template>
    </p>
  </div>
</template>
