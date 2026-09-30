<script setup>
// PATCH LOCAL (fork) - campos próprios da regra de exibição (Movidesk: Regras
// para exibição): condições combinadas (todas precisam bater), condições
// independentes (pelo menos uma) e os campos que a regra mostra, na ordem.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useTicketCatalog } from 'dashboard/composables/useTicketCatalog';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import RuleConditionRow from './RuleConditionRow.vue';
import RuleFieldRow from './RuleFieldRow.vue';

const record = defineModel('record', { type: Object, required: true });

const GROUPS = ['all', 'any'];
const NEW_RULE_FIELD = {
  columns: 12,
  visible_to_clients: false,
  editable_by_clients: false,
  editable_by_agents: true,
  required_on: 'nao_exigir',
};

const { t } = useI18n();
const { state } = useTicketCatalog();

const fieldToAdd = ref('');

const fieldsById = computed(
  () => new Map(state.customFields.map(field => [field.id, field]))
);

const fieldName = fieldId => {
  const field = fieldsById.value.get(fieldId);
  if (!field) return `#${fieldId}`;
  return field.active
    ? field.name
    : t('TICKET_CATALOG.FORM.INACTIVE_OPTION', { name: field.name });
};

// Só campo ativo que a regra ainda não mostra.
const addableFields = computed(() => {
  const used = new Set(record.value.fields.map(item => item.field_id));
  return state.customFields
    .filter(field => field.active && !used.has(field.id))
    .map(field => ({ value: field.id, label: field.name }));
});

// Índices na lista completa, pra editar/remover a condição certa.
const conditionsOf = group =>
  record.value.conditions
    .map((condition, index) => ({ condition, index }))
    .filter(({ condition }) => condition.group === group);

const addCondition = group => {
  record.value.conditions = [
    ...record.value.conditions,
    { group, attribute: 'servico', operator: 'equal_to', value: '' },
  ];
};

const updateCondition = (index, condition) => {
  record.value.conditions = record.value.conditions.map((item, position) =>
    position === index ? condition : item
  );
};

const removeCondition = index => {
  record.value.conditions = record.value.conditions.filter(
    (_, position) => position !== index
  );
};

const addField = fieldId => {
  if (!fieldId) return;
  record.value.fields = [
    ...record.value.fields,
    { field_id: fieldId, ...NEW_RULE_FIELD },
  ];
  fieldToAdd.value = '';
};

const moveField = (index, offset) => {
  const fields = [...record.value.fields];
  [fields[index], fields[index + offset]] = [
    fields[index + offset],
    fields[index],
  ];
  record.value.fields = fields;
};

const removeField = index => {
  record.value.fields = record.value.fields.filter(
    (_, position) => position !== index
  );
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <InfoCard
      :title="t('TICKET_CATALOG.FIELD_RULES.FORM.CONDITIONS_TITLE')"
      icon="i-lucide-filter"
    >
      <template #actions>
        <span />
      </template>
      <div class="flex flex-col gap-5">
        <section
          v-for="group in GROUPS"
          :key="group"
          class="flex flex-col gap-2"
        >
          <div>
            <h3 class="mb-0 text-sm font-medium text-n-slate-12">
              {{ t(`TICKET_CATALOG.FIELD_RULES.GROUPS.${group}.TITLE`) }}
            </h3>
            <p class="mb-0 text-xs text-n-slate-11">
              {{ t(`TICKET_CATALOG.FIELD_RULES.GROUPS.${group}.HINT`) }}
            </p>
          </div>
          <RuleConditionRow
            v-for="{ condition, index } in conditionsOf(group)"
            :key="index"
            :condition="condition"
            @update:condition="value => updateCondition(index, value)"
            @remove="removeCondition(index)"
          />
          <div>
            <Button
              :label="t('TICKET_CATALOG.FIELD_RULES.FORM.ADD_CONDITION')"
              icon="i-lucide-plus"
              slate
              faded
              xs
              @click="addCondition(group)"
            />
          </div>
        </section>
        <p class="mb-0 text-xs text-n-slate-10">
          {{ t('TICKET_CATALOG.FIELD_RULES.FORM.CONDITIONS_HINT') }}
        </p>
      </div>
    </InfoCard>

    <InfoCard
      :title="t('TICKET_CATALOG.FIELD_RULES.FORM.FIELDS_TITLE')"
      icon="i-lucide-list-checks"
    >
      <template #actions>
        <span />
      </template>
      <div class="flex flex-col gap-3">
        <p class="mb-0 text-xs text-n-slate-11">
          {{ t('TICKET_CATALOG.FIELD_RULES.FORM.FIELDS_HINT') }}
        </p>
        <RuleFieldRow
          v-for="(item, index) in record.fields"
          :key="item.field_id"
          v-model:item="record.fields[index]"
          :field-name="fieldName(item.field_id)"
          :is-first="index === 0"
          :is-last="index === record.fields.length - 1"
          @move-up="moveField(index, -1)"
          @move-down="moveField(index, 1)"
          @remove="removeField(index)"
        />
        <div class="sm:max-w-md">
          <ComboBox
            v-model="fieldToAdd"
            :options="addableFields"
            :placeholder="t('TICKET_CATALOG.FIELD_RULES.FORM.ADD_FIELD')"
            @update:model-value="addField"
          />
        </div>
      </div>
    </InfoCard>
  </div>
</template>
