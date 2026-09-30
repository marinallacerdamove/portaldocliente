<script setup>
// PATCH LOCAL (fork) - um campo exibido pela regra: largura (colunas de 12),
// quem vê e quem edita (cliente no Portal, agente) e quando é obrigatório.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import { REQUIRED_ON } from 'dashboard/helper/ticketFieldRules';

defineProps({
  fieldName: { type: String, required: true },
  isFirst: { type: Boolean, default: false },
  isLast: { type: Boolean, default: false },
});

defineEmits(['moveUp', 'moveDown', 'remove']);

const item = defineModel('item', { type: Object, required: true });

const FLAGS = [
  'visible_to_clients',
  'editable_by_clients',
  'editable_by_agents',
];
const MAX_COLUMNS = 12;

const { t } = useI18n();

const requiredOptions = computed(() =>
  REQUIRED_ON.map(moment => ({
    value: moment,
    label: t(`TICKET_CATALOG.FIELD_RULES.REQUIRED_ON.${moment}`),
  }))
);

const columns = computed({
  get: () => String(item.value.columns),
  set: value => {
    const number = Math.round(Number(value)) || MAX_COLUMNS;
    item.value.columns = Math.min(Math.max(number, 1), MAX_COLUMNS);
  },
});
</script>

<template>
  <div class="flex flex-col gap-3 p-3 border rounded-lg border-n-weak">
    <div class="flex items-start justify-between gap-2">
      <span class="text-sm font-medium break-words text-n-slate-12">
        {{ fieldName }}
      </span>
      <div class="flex items-center shrink-0">
        <Button
          icon="i-lucide-arrow-up"
          slate
          ghost
          xs
          :disabled="isFirst"
          @click="$emit('moveUp')"
        />
        <Button
          icon="i-lucide-arrow-down"
          slate
          ghost
          xs
          :disabled="isLast"
          @click="$emit('moveDown')"
        />
        <Button
          v-tooltip.top="t('TICKET_CATALOG.FIELD_RULES.FORM.REMOVE')"
          icon="i-lucide-trash-2"
          ruby
          ghost
          xs
          @click="$emit('remove')"
        />
      </div>
    </div>
    <div class="grid gap-3 sm:grid-cols-[6rem_minmax(0,1fr)]">
      <Input
        v-model="columns"
        type="number"
        :min="1"
        :max="MAX_COLUMNS"
        :label="t('TICKET_CATALOG.FIELD_RULES.FORM.COLUMNS_LABEL')"
      />
      <SelectInput
        v-model="item.required_on"
        :label="t('TICKET_CATALOG.FIELD_RULES.FORM.REQUIRED_ON_LABEL')"
        :options="requiredOptions"
      />
    </div>
    <div class="flex flex-wrap gap-x-6 gap-y-2">
      <label
        v-for="flag in FLAGS"
        :key="flag"
        class="flex items-center gap-2 mb-0 text-sm cursor-pointer text-n-slate-12"
      >
        <Checkbox v-model="item[flag]" />
        {{ t(`TICKET_CATALOG.FIELD_RULES.FLAGS.${flag}`) }}
      </label>
    </div>
  </div>
</template>
