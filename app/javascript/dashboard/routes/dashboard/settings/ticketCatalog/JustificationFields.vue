<script setup>
// PATCH LOCAL (fork) - campos próprios da justificativa: em quais status ela
// pode ser usada.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useTicketCatalog } from 'dashboard/composables/useTicketCatalog';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import ToggleChips from './ToggleChips.vue';

const record = defineModel('record', { type: Object, required: true });

const { t } = useI18n();
const { state } = useTicketCatalog();

// Status inativo só aparece se já estiver marcado (pra poder desmarcar).
const statusOptions = computed(() =>
  state.statuses
    .filter(
      status => status.active || record.value.status_ids.includes(status.id)
    )
    .map(status => ({
      id: status.id,
      name: status.active
        ? status.name
        : t('TICKET_CATALOG.FORM.INACTIVE_OPTION', { name: status.name }),
    }))
);
</script>

<template>
  <InfoCard
    :title="t('TICKET_CATALOG.JUSTIFICATIONS.FORM.STATUSES_TITLE')"
    icon="i-lucide-flag"
  >
    <template #actions>
      <span />
    </template>
    <div class="flex flex-col gap-3">
      <p class="mb-0 text-xs text-n-slate-11">
        {{ t('TICKET_CATALOG.JUSTIFICATIONS.FORM.STATUSES_HINT') }}
      </p>
      <ToggleChips
        v-model="record.status_ids"
        :options="statusOptions"
        :empty-message="t('TICKET_CATALOG.JUSTIFICATIONS.FORM.NO_STATUSES')"
      />
    </div>
  </InfoCard>
</template>
