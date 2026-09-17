<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { generateRuleId } from 'dashboard/helper/botFlowHelper';

const props = defineProps({
  variableOptions: { type: Array, default: () => [] },
});

const modelValue = defineModel({ type: Object, required: true });
const { t } = useI18n();

const operatorOptions = computed(() => [
  { id: 'equals', name: t('BOT_FLOW.EDITOR.PANEL.CONDITION.OPERATORS.EQUALS') },
  {
    id: 'contains',
    name: t('BOT_FLOW.EDITOR.PANEL.CONDITION.OPERATORS.CONTAINS'),
  },
  {
    id: 'is_present',
    name: t('BOT_FLOW.EDITOR.PANEL.CONDITION.OPERATORS.IS_PRESENT'),
  },
  { id: 'regex', name: t('BOT_FLOW.EDITOR.PANEL.CONDITION.OPERATORS.REGEX') },
]);

const variableModel = computed({
  get: () =>
    props.variableOptions.find(o => o.id === modelValue.value.variable) || null,
  set: option => {
    modelValue.value.variable = option?.id || '';
  },
});

const operatorModelFor = rule =>
  computed({
    get: () =>
      operatorOptions.value.find(o => o.id === rule.operator) ||
      operatorOptions.value[0],
    set: option => {
      rule.operator = option?.id || 'equals';
    },
  });

const addRule = () => {
  modelValue.value.rules = [
    ...(modelValue.value.rules || []),
    { id: generateRuleId(), operator: 'equals', value: '' },
  ];
};

const removeRule = index => {
  modelValue.value.rules = modelValue.value.rules.filter((_, i) => i !== index);
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <WithLabel
      :label="t('BOT_FLOW.EDITOR.PANEL.CONDITION.VARIABLE_LABEL')"
      name="variable"
    >
      <SingleSelect v-model="variableModel" :options="variableOptions" />
    </WithLabel>

    <div class="flex flex-col gap-3">
      <span class="text-sm font-medium text-n-slate-11">{{
        t('BOT_FLOW.EDITOR.PANEL.CONDITION.RULES_LABEL')
      }}</span>
      <div
        v-for="(rule, index) in modelValue.rules || []"
        :key="rule.id"
        class="flex flex-col gap-2 p-2 border border-n-weak rounded-lg"
      >
        <div class="flex items-center gap-2">
          <SingleSelect
            v-model="operatorModelFor(rule).value"
            :options="operatorOptions"
            class="flex-1"
          />
          <NextButton
            icon="i-lucide-trash-2"
            slate
            ghost
            sm
            @click="removeRule(index)"
          />
        </div>
        <NextInput
          v-if="rule.operator !== 'is_present'"
          v-model="rule.value"
          :placeholder="t('BOT_FLOW.EDITOR.PANEL.CONDITION.VALUE_PLACEHOLDER')"
        />
      </div>
      <NextButton
        sm
        slate
        faded
        icon="i-lucide-plus"
        :label="t('BOT_FLOW.EDITOR.PANEL.CONDITION.ADD_RULE')"
        @click="addRule"
      />
    </div>
  </div>
</template>
