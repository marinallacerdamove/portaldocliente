<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import VariableSelect from '../components/variables/VariableSelect.vue';
import {
  generateBranchId,
  generateConditionId,
} from 'dashboard/helper/botFlowHelper';

defineProps({
  entries: { type: Array, default: () => [] },
  recentIds: { type: Array, default: () => [] },
  recordUsage: { type: Function, default: () => {} },
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

const logicOptions = computed(() => [
  { id: 'and', name: t('BOT_FLOW.EDITOR.PANEL.CONDITION.LOGIC.AND') },
  { id: 'or', name: t('BOT_FLOW.EDITOR.PANEL.CONDITION.LOGIC.OR') },
]);

const operatorModelFor = condition =>
  computed({
    get: () =>
      operatorOptions.value.find(o => o.id === condition.operator) ||
      operatorOptions.value[0],
    set: option => {
      condition.operator = option?.id || 'equals';
    },
  });

const logicModelFor = branch =>
  computed({
    get: () =>
      logicOptions.value.find(o => o.id === branch.logic) ||
      logicOptions.value[0],
    set: option => {
      branch.logic = option?.id || 'and';
    },
  });

const addBranch = () => {
  modelValue.value.branches = [
    ...(modelValue.value.branches || []),
    {
      id: generateBranchId(),
      logic: 'and',
      conditions: [
        {
          id: generateConditionId(),
          variable: '',
          operator: 'equals',
          value: '',
        },
      ],
    },
  ];
};

const removeBranch = index => {
  modelValue.value.branches = modelValue.value.branches.filter(
    (_, i) => i !== index
  );
};

const addCondition = branch => {
  branch.conditions = [
    ...(branch.conditions || []),
    { id: generateConditionId(), variable: '', operator: 'equals', value: '' },
  ];
};

const removeCondition = (branch, index) => {
  branch.conditions = branch.conditions.filter((_, i) => i !== index);
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <p class="text-xs text-n-slate-10 bg-n-slate-2 rounded-lg p-2">
      {{ t('BOT_FLOW.EDITOR.PANEL.CONDITION.INTRO_HELP') }}
    </p>

    <div
      v-for="(branch, branchIndex) in modelValue.branches || []"
      :key="branch.id"
      class="flex flex-col gap-3 p-3 border border-n-weak rounded-lg"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{
            t('BOT_FLOW.EDITOR.PANEL.CONDITION.BRANCH_LABEL', {
              n: branchIndex + 1,
            })
          }}
        </span>
        <NextButton
          icon="i-lucide-trash-2"
          slate
          ghost
          sm
          @click="removeBranch(branchIndex)"
        />
      </div>

      <SingleSelect
        v-model="logicModelFor(branch).value"
        :options="logicOptions"
        disable-search
        disable-deselect
      />

      <div
        v-for="(condition, conditionIndex) in branch.conditions || []"
        :key="condition.id"
        class="flex flex-col gap-2"
      >
        <div class="flex items-center gap-2">
          <VariableSelect
            v-model="condition.variable"
            :entries="entries"
            :recent-ids="recentIds"
            :record-usage="recordUsage"
            :placeholder="
              t('BOT_FLOW.EDITOR.PANEL.CONDITION.VARIABLE_PLACEHOLDER')
            "
            class="flex-1"
          />
          <SingleSelect
            v-model="operatorModelFor(condition).value"
            :options="operatorOptions"
            disable-search
            disable-deselect
            class="flex-1"
          />
          <NextButton
            icon="i-lucide-x"
            slate
            ghost
            sm
            @click="removeCondition(branch, conditionIndex)"
          />
        </div>
        <NextInput
          v-if="condition.operator !== 'is_present'"
          v-model="condition.value"
          :placeholder="t('BOT_FLOW.EDITOR.PANEL.CONDITION.VALUE_PLACEHOLDER')"
        />
      </div>

      <NextButton
        sm
        slate
        faded
        icon="i-lucide-plus"
        :label="t('BOT_FLOW.EDITOR.PANEL.CONDITION.ADD_CONDITION')"
        @click="addCondition(branch)"
      />
    </div>

    <NextButton
      sm
      slate
      faded
      icon="i-lucide-plus"
      :label="t('BOT_FLOW.EDITOR.PANEL.CONDITION.ADD_BRANCH')"
      @click="addBranch"
    />
  </div>
</template>
