<script setup>
// PATCH LOCAL (fork) - uma condição da regra de exibição: o que comparar
// (serviço, tipo de solicitação, outro campo adicional...), como e com qual
// valor. As opções de valor vêm dos cadastros; valor gravado que não está
// mais na lista (item inativado ou que não existia no Movidesk) continua
// aparecendo pelo nome.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useTicketCatalog } from 'dashboard/composables/useTicketCatalog';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import {
  CONDITION_ATTRIBUTES,
  CONDITION_OPERATORS,
  OPTION_FIELD_TYPES,
  ORIGINS,
  STATUS_NOT_CONCLUDED,
} from 'dashboard/helper/ticketFieldRules';

defineEmits(['remove']);

const condition = defineModel('condition', { type: Object, required: true });

const { t } = useI18n();
const { state } = useTicketCatalog();
const teams = useMapGetter('teams/getTeams');
const agents = useMapGetter('agents/getAgents');

const byName = names => names.map(name => ({ value: name, label: name }));

const attributeOptions = computed(() =>
  CONDITION_ATTRIBUTES.map(attribute => ({
    value: attribute,
    label: t(`TICKET_CATALOG.FIELD_RULES.ATTRIBUTES.${attribute}`),
  }))
);

const operatorOptions = computed(() =>
  CONDITION_OPERATORS.map(operator => ({
    value: operator,
    label: t(`TICKET_CATALOG.FIELD_RULES.OPERATORS.${operator}`),
  }))
);

const fieldOptions = computed(() =>
  state.customFields.map(field => ({
    value: field.id,
    label: field.active
      ? field.name
      : t('TICKET_CATALOG.FORM.INACTIVE_OPTION', { name: field.name }),
  }))
);

const selectedField = computed(() =>
  state.customFields.find(field => field.id === condition.value.field_id)
);

// null = valor digitado (empresa, campo de texto).
const valueOptions = computed(() => {
  switch (condition.value.attribute) {
    case 'servico':
      return byName(state.services.map(service => service.full_name));
    case 'tipo_de_solicitacao':
      return byName(state.categories.map(category => category.name));
    case 'status':
      return [
        {
          value: STATUS_NOT_CONCLUDED,
          label: t('TICKET_CATALOG.FIELD_RULES.STATUS_NOT_CONCLUDED'),
        },
        ...byName(state.statuses.map(status => status.name)),
      ];
    case 'origem':
      return ORIGINS.map(origin => ({
        value: origin,
        label: t(`TICKET_CATALOG.FIELD_RULES.ORIGINS.${origin}`),
      }));
    case 'equipe':
      return byName(teams.value.map(team => team.name));
    case 'responsavel':
      return byName(agents.value.map(agent => agent.name));
    case 'campo':
      return OPTION_FIELD_TYPES.includes(selectedField.value?.field_type)
        ? byName(selectedField.value.options)
        : null;
    default:
      return null;
  }
});

const onAttributeChange = attribute => {
  condition.value = {
    group: condition.value.group,
    attribute,
    operator: condition.value.operator,
    value: '',
    ...(attribute === 'campo' ? { field_id: null } : {}),
  };
};

const onFieldChange = fieldId => {
  condition.value = {
    ...condition.value,
    field_id: fieldId || null,
    value: '',
  };
};
</script>

<template>
  <div
    class="grid items-start gap-2 p-2 border rounded-lg border-n-weak sm:grid-cols-[10rem_minmax(0,1fr)_9rem_minmax(0,1.4fr)_auto]"
  >
    <SelectInput
      :model-value="condition.attribute"
      :options="attributeOptions"
      @update:model-value="onAttributeChange"
    />
    <ComboBox
      v-if="condition.attribute === 'campo'"
      :model-value="condition.field_id || ''"
      :options="fieldOptions"
      :placeholder="t('TICKET_CATALOG.FIELD_RULES.FORM.FIELD_PLACEHOLDER')"
      @update:model-value="onFieldChange"
    />
    <span v-else class="hidden sm:block" />
    <SelectInput v-model="condition.operator" :options="operatorOptions" />
    <template v-if="condition.operator !== 'is_present'">
      <ComboBox
        v-if="valueOptions"
        v-model="condition.value"
        :options="valueOptions"
        :display-label="condition.value"
        :placeholder="t('TICKET_CATALOG.FIELD_RULES.FORM.VALUE_PLACEHOLDER')"
      />
      <Input
        v-else
        v-model="condition.value"
        :placeholder="t('TICKET_CATALOG.FIELD_RULES.FORM.VALUE_PLACEHOLDER')"
      />
    </template>
    <span v-else class="hidden sm:block" />
    <Button
      v-tooltip.top="t('TICKET_CATALOG.FIELD_RULES.FORM.REMOVE')"
      icon="i-lucide-trash-2"
      ruby
      ghost
      sm
      @click="$emit('remove')"
    />
  </div>
</template>
