<script setup>
// PATCH LOCAL (fork) - campos próprios do campo adicional: tipo, texto de
// ajuda e opções (uma por linha, só nos tipos de lista). A chave é gerada do
// nome na criação e não muda; só aparece aqui pra consulta.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { OPTION_FIELD_TYPES } from 'dashboard/helper/ticketFieldRules';
import { FIELD_TYPES } from './constants';

const record = defineModel('record', { type: Object, required: true });

const OPTIONS_MAX_LENGTH = 20000;

const { t } = useI18n();

const typeOptions = computed(() =>
  FIELD_TYPES.map(type => ({
    value: type,
    label: t(`TICKET_CATALOG.CUSTOM_FIELDS.TYPES.${type}`),
  }))
);

const hasOptions = computed(() =>
  OPTION_FIELD_TYPES.includes(record.value.field_type)
);

const optionsText = computed({
  get: () => record.value.options.join('\n'),
  set: text => {
    record.value.options = text.split('\n');
  },
});
</script>

<template>
  <InfoCard
    :title="t('TICKET_CATALOG.CUSTOM_FIELDS.FORM.DETAILS_TITLE')"
    icon="i-lucide-text-cursor-input"
  >
    <template #actions>
      <span />
    </template>
    <div class="flex flex-col gap-4">
      <div class="grid gap-4 sm:grid-cols-2">
        <SelectInput
          id="custom-field-type"
          v-model="record.field_type"
          :label="t('TICKET_CATALOG.CUSTOM_FIELDS.FORM.TYPE_LABEL')"
          :options="typeOptions"
        />
        <Input
          v-if="record.key"
          id="custom-field-key"
          :model-value="record.key"
          :label="t('TICKET_CATALOG.CUSTOM_FIELDS.FORM.KEY_LABEL')"
          :message="t('TICKET_CATALOG.CUSTOM_FIELDS.FORM.KEY_HINT')"
          disabled
        />
      </div>
      <Input
        id="custom-field-hint"
        v-model="record.hint"
        :label="t('TICKET_CATALOG.CUSTOM_FIELDS.FORM.HINT_LABEL')"
        :placeholder="t('TICKET_CATALOG.CUSTOM_FIELDS.FORM.HINT_PLACEHOLDER')"
      />
      <TextArea
        v-if="hasOptions"
        v-model="optionsText"
        :label="t('TICKET_CATALOG.CUSTOM_FIELDS.FORM.OPTIONS_LABEL')"
        :placeholder="
          t('TICKET_CATALOG.CUSTOM_FIELDS.FORM.OPTIONS_PLACEHOLDER')
        "
        :max-length="OPTIONS_MAX_LENGTH"
        :message="t('TICKET_CATALOG.CUSTOM_FIELDS.FORM.OPTIONS_HINT')"
        auto-height
        min-height="8rem"
      />
    </div>
  </InfoCard>
</template>
