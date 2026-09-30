<script setup>
// PATCH LOCAL (fork) - campos próprios do status: tipo do status (vira o
// status da conversa no Chatwoot) e se ele exige justificativa.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import { STATUS_BASES } from './constants';

const record = defineModel('record', { type: Object, required: true });

const { t } = useI18n();

const baseOptions = computed(() =>
  STATUS_BASES.map(base => ({
    value: base,
    label: t(`TICKET_CATALOG.STATUS_BASES.${base}`),
  }))
);
</script>

<template>
  <InfoCard
    :title="t('TICKET_CATALOG.STATUSES.FORM.BEHAVIOR_TITLE')"
    icon="i-lucide-flag"
  >
    <template #actions>
      <span />
    </template>
    <div class="flex flex-col gap-4">
      <div class="flex flex-col gap-1 sm:max-w-md">
        <SelectInput
          id="status-base"
          v-model="record.base"
          :label="t('TICKET_CATALOG.STATUSES.FORM.BASE_LABEL')"
          :options="baseOptions"
        />
        <p class="mb-0 text-xs text-n-slate-10">
          {{ t('TICKET_CATALOG.STATUSES.FORM.BASE_HINT') }}
        </p>
      </div>
      <SettingsToggleSection
        v-model="record.requires_justification"
        :header="t('TICKET_CATALOG.STATUSES.FORM.REQUIRES_JUSTIFICATION_LABEL')"
        :description="
          t('TICKET_CATALOG.STATUSES.FORM.REQUIRES_JUSTIFICATION_HINT')
        "
      />
    </div>
  </InfoCard>
</template>
