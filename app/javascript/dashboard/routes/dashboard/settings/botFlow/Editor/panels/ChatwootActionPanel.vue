<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import MultiSelect from 'dashboard/components-next/filter/inputs/MultiSelect.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';

const modelValue = defineModel({ type: Object, required: true });
const { t } = useI18n();
const store = useStore();

const teams = useMapGetter('teams/getTeams');
const labels = useMapGetter('labels/getLabels');

onMounted(() => {
  if (!teams.value.length) store.dispatch('teams/get');
  if (!labels.value.length) store.dispatch('labels/get');
});

const actionOptions = computed(() =>
  [
    'assign_team',
    'add_label',
    'set_custom_attribute',
    'resolve_conversation',
  ].map(id => ({
    id,
    name: t(
      `BOT_FLOW.EDITOR.PANEL.CHATWOOT_ACTION.ACTIONS.${id.toUpperCase()}`
    ),
  }))
);

const actionModel = computed({
  get: () =>
    actionOptions.value.find(o => o.id === modelValue.value.action_name) ||
    actionOptions.value[0],
  set: option => {
    modelValue.value.action_name = option?.id || 'assign_team';
    modelValue.value.action_params = [];
  },
});

const teamOptions = computed(() =>
  teams.value.map(team => ({ id: team.id, name: team.name }))
);
const teamModel = computed({
  get: () =>
    teamOptions.value.find(o => o.id === modelValue.value.action_params?.[0]) ||
    null,
  set: option => {
    modelValue.value.action_params = option ? [option.id] : [];
  },
});

const labelOptions = computed(() =>
  labels.value.map(label => ({ id: label.title, name: label.title }))
);
const labelModel = computed({
  get: () =>
    (modelValue.value.action_params || [])
      .map(id => labelOptions.value.find(o => o.id === id))
      .filter(Boolean),
  set: options => {
    modelValue.value.action_params = (options || []).map(o => o.id);
  },
});

const attributeKeyModel = computed({
  get: () => modelValue.value.action_params?.[0] || '',
  set: value => {
    modelValue.value.action_params = [
      value,
      modelValue.value.action_params?.[1] || '',
    ];
  },
});
const attributeValueModel = computed({
  get: () => modelValue.value.action_params?.[1] || '',
  set: value => {
    modelValue.value.action_params = [
      modelValue.value.action_params?.[0] || '',
      value,
    ];
  },
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <WithLabel
      :label="t('BOT_FLOW.EDITOR.PANEL.CHATWOOT_ACTION.ACTION_LABEL')"
      name="action_name"
    >
      <SingleSelect
        v-model="actionModel"
        :options="actionOptions"
        disable-search
        disable-deselect
      />
    </WithLabel>

    <WithLabel
      v-if="modelValue.action_name === 'assign_team'"
      :label="t('BOT_FLOW.EDITOR.PANEL.CHATWOOT_ACTION.TEAM_LABEL')"
      name="team"
    >
      <SingleSelect v-model="teamModel" :options="teamOptions" />
    </WithLabel>

    <WithLabel
      v-if="modelValue.action_name === 'add_label'"
      :label="t('BOT_FLOW.EDITOR.PANEL.CHATWOOT_ACTION.LABEL_LABEL')"
      name="labels"
    >
      <MultiSelect v-model="labelModel" :options="labelOptions" />
    </WithLabel>

    <template v-if="modelValue.action_name === 'set_custom_attribute'">
      <WithLabel
        :label="t('BOT_FLOW.EDITOR.PANEL.CHATWOOT_ACTION.ATTRIBUTE_KEY_LABEL')"
        :help-message="
          t('BOT_FLOW.EDITOR.PANEL.CHATWOOT_ACTION.ATTRIBUTE_HELP')
        "
        name="attribute_key"
      >
        <NextInput v-model="attributeKeyModel" />
      </WithLabel>
      <WithLabel
        :label="
          t('BOT_FLOW.EDITOR.PANEL.CHATWOOT_ACTION.ATTRIBUTE_VALUE_LABEL')
        "
        name="attribute_value"
      >
        <NextInput v-model="attributeValueModel" />
      </WithLabel>
    </template>
  </div>
</template>
