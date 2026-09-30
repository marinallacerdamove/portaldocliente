<script setup>
// PATCH LOCAL (fork) - campos próprios da categoria: urgências permitidas
// (nenhuma marcada = todas).
import { useI18n } from 'vue-i18n';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import { PRIORITIES } from './constants';

const record = defineModel('record', { type: Object, required: true });

const { t } = useI18n();

// Mantém a ordem de PRIORITIES, independente da ordem dos cliques.
const togglePriority = (priority, checked) => {
  const selected = new Set(record.value.allowed_priorities);
  if (checked) selected.add(priority);
  else selected.delete(priority);
  record.value.allowed_priorities = PRIORITIES.filter(item =>
    selected.has(item)
  );
};
</script>

<template>
  <InfoCard
    :title="t('TICKET_CATALOG.CATEGORIES.FORM.PRIORITIES_TITLE')"
    icon="i-lucide-gauge"
  >
    <template #actions>
      <span />
    </template>
    <div class="flex flex-col gap-3">
      <p class="mb-0 text-xs text-n-slate-11">
        {{ t('TICKET_CATALOG.CATEGORIES.FORM.PRIORITIES_HINT') }}
      </p>
      <div class="flex flex-wrap gap-x-6 gap-y-3">
        <label
          v-for="priority in PRIORITIES"
          :key="priority"
          class="flex items-center gap-2 mb-0 text-sm cursor-pointer text-n-slate-12"
        >
          <Checkbox
            :model-value="record.allowed_priorities.includes(priority)"
            @update:model-value="checked => togglePriority(priority, checked)"
          />
          {{ t(`TICKET_CATALOG.PRIORITIES.${priority}`) }}
        </label>
      </div>
    </div>
  </InfoCard>
</template>
