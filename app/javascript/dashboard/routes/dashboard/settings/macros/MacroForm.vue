<script setup>
// PATCH LOCAL (fork) - formulário da macro em cards (padrão das fichas do
// fork): "Principal" (nome, grupo, compartilhamento pessoal / equipes / todos)
// e "Ações" em cartões reordenáveis. Substitui o fluxo em nós do upstream.
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import { useMapGetter } from 'dashboard/composables/store';
import { validateActions } from 'dashboard/helper/validations';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import MacroActionCard from './MacroActionCard.vue';
import { getFileName } from './macroHelper';

const props = defineProps({
  macroData: { type: Object, required: true },
  canManagePublicMacros: { type: Boolean, default: false },
  readOnly: { type: Boolean, default: false },
  isEdit: { type: Boolean, default: false },
  // Grupos já usados em outras macros, sugeridos no campo "Grupo".
  groups: { type: Array, default: () => [] },
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const teams = useMapGetter('teams/getTeams');
const agents = useMapGetter('agents/getAgents');

const VISIBILITY_OPTIONS = [
  {
    value: 'personal',
    icon: 'i-lucide-user-round',
    title: 'MACROS.EDITOR.VISIBILITY.PERSONAL.LABEL',
    description: 'MACROS.EDITOR.VISIBILITY.PERSONAL.DESCRIPTION',
    adminOnly: false,
  },
  {
    value: 'team',
    icon: 'i-lucide-users-round',
    title: 'MACROS.EDITOR.VISIBILITY.TEAM.LABEL',
    description: 'MACROS.EDITOR.VISIBILITY.TEAM.DESCRIPTION',
    adminOnly: true,
  },
  {
    value: 'global',
    icon: 'i-lucide-globe',
    title: 'MACROS.EDITOR.VISIBILITY.GLOBAL.LABEL',
    description: 'MACROS.EDITOR.VISIBILITY.GLOBAL.DESCRIPTION',
    adminOnly: true,
  },
];

const macro = ref(null);
const errors = ref({});
const nameError = ref('');
const teamsError = ref('');

watch(
  () => props.macroData,
  value => {
    macro.value = {
      team_ids: [],
      user_ids: [],
      group_name: '',
      ...value,
    };
    errors.value = {};
  },
  { immediate: true }
);

const files = computed(() => macro.value.files || []);

// Chave estável por ação pro arrastar-e-soltar, sem gravar nada na ação (ela
// vai crua pro backend).
const actionKeys = new WeakMap();
let nextActionKey = 0;
const actionKey = item => {
  if (!actionKeys.has(item)) {
    nextActionKey += 1;
    actionKeys.set(item, nextActionKey);
  }
  return actionKeys.get(item);
};

const isOptionDisabled = option =>
  props.readOnly || (option.adminOnly && !props.canManagePublicMacros);

const setVisibility = option => {
  if (isOptionDisabled(option)) return;
  macro.value.visibility = option.value;
  teamsError.value = '';
};

const toggleTeam = teamId => {
  const selected = new Set(macro.value.team_ids);
  if (selected.has(teamId)) selected.delete(teamId);
  else selected.add(teamId);
  macro.value.team_ids = [...selected];
  teamsError.value = '';
};

const toggleAgent = agentId => {
  const selected = new Set(macro.value.user_ids);
  if (selected.has(agentId)) selected.delete(agentId);
  else selected.add(agentId);
  macro.value.user_ids = [...selected];
  teamsError.value = '';
};

const addAction = () => {
  macro.value.actions.push({ action_name: 'fill_reply', action_params: [] });
};

const removeAction = index => {
  macro.value.actions.splice(index, 1);
  errors.value = {};
};

const resetAction = index => {
  macro.value.actions[index].action_params = [];
  const { [`action_${index}`]: _removed, ...rest } = errors.value;
  errors.value = rest;
};

const submit = () => {
  nameError.value = macro.value.name?.trim()
    ? ''
    : t('MACROS.EDITOR.NAME_REQUIRED');
  teamsError.value =
    macro.value.visibility === 'team' &&
    !macro.value.team_ids.length &&
    !macro.value.user_ids.length
      ? t('MACROS.EDITOR.TEAMS_REQUIRED')
      : '';
  errors.value = validateActions(macro.value.actions);
  if (nameError.value || teamsError.value || Object.keys(errors.value).length)
    return;

  emit('submit', {
    ...macro.value,
    team_ids: macro.value.visibility === 'team' ? macro.value.team_ids : [],
    user_ids: macro.value.visibility === 'team' ? macro.value.user_ids : [],
  });
};
</script>

<template>
  <div class="flex flex-col w-full max-w-4xl gap-4 py-6">
    <header class="flex flex-wrap items-start justify-between gap-3">
      <div class="flex flex-col gap-1">
        <h1 class="my-0 text-xl font-semibold text-n-slate-12">
          {{
            isEdit
              ? t('MACROS.EDITOR.EDIT_TITLE')
              : t('MACROS.EDITOR.NEW_TITLE')
          }}
        </h1>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('MACROS.EDITOR.SUBTITLE') }}
        </p>
      </div>
      <div class="flex items-center gap-2">
        <Button
          :label="t('MACROS.EDITOR.CANCEL')"
          ghost
          slate
          sm
          @click="emit('cancel')"
        />
        <Button
          :label="t('MACROS.EDITOR.SUBMIT')"
          sm
          :is-loading="isSaving"
          :disabled="readOnly || isSaving"
          @click="submit"
        />
      </div>
    </header>

    <p
      v-if="readOnly"
      class="px-3 py-2 mb-0 text-sm border rounded-xl bg-n-amber-3 border-n-amber-4 text-n-amber-11"
    >
      {{ t('MACROS.EDITOR.READ_ONLY') }}
    </p>

    <div
      :inert="readOnly"
      class="flex flex-col gap-4"
      :class="{ 'opacity-75': readOnly }"
    >
      <InfoCard
        :title="t('MACROS.EDITOR.MAIN_TITLE')"
        icon="i-lucide-settings-2"
      >
        <template #actions>
          <span />
        </template>
        <div class="flex flex-col gap-5">
          <div class="grid gap-4 sm:grid-cols-2">
            <Input
              id="macro-name"
              v-model="macro.name"
              :label="t('MACROS.EDITOR.NAME_LABEL')"
              :placeholder="t('MACROS.EDITOR.NAME_PLACEHOLDER')"
              :message="nameError"
              :message-type="nameError ? 'error' : 'info'"
            />
            <div class="flex flex-col gap-1">
              <Input
                id="macro-group"
                v-model="macro.group_name"
                list="macro-group-options"
                :label="t('MACROS.EDITOR.GROUP_LABEL')"
                :placeholder="t('MACROS.EDITOR.GROUP_PLACEHOLDER')"
              />
              <datalist id="macro-group-options">
                <option v-for="group in groups" :key="group" :value="group" />
              </datalist>
            </div>
          </div>

          <div class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('MACROS.EDITOR.VISIBILITY.LABEL') }}
            </span>
            <div class="grid gap-2 sm:grid-cols-3">
              <button
                v-for="option in VISIBILITY_OPTIONS"
                :key="option.value"
                type="button"
                class="flex items-start gap-2 p-3 rounded-lg outline outline-1 text-start transition-colors"
                :class="[
                  macro.visibility === option.value
                    ? 'outline-n-brand bg-n-alpha-2'
                    : 'outline-n-weak hover:bg-n-alpha-1',
                  isOptionDisabled(option)
                    ? 'opacity-50 cursor-not-allowed'
                    : '',
                ]"
                :disabled="isOptionDisabled(option)"
                @click="setVisibility(option)"
              >
                <span
                  :class="option.icon"
                  class="size-4 mt-0.5 shrink-0 text-n-slate-11"
                />
                <span class="flex flex-col gap-0.5">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ t(option.title) }}
                  </span>
                  <span class="text-xs text-n-slate-11">
                    {{ t(option.description) }}
                  </span>
                </span>
              </button>
            </div>
            <p
              v-if="!canManagePublicMacros"
              class="mb-0 text-xs text-n-slate-10"
            >
              {{ t('MACROS.EDITOR.VISIBILITY.AGENT_HINT') }}
            </p>
          </div>

          <div v-if="macro.visibility === 'team'" class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('MACROS.EDITOR.TEAMS_LABEL') }}
            </span>
            <div class="flex flex-wrap gap-2">
              <Button
                v-for="team in teams"
                :key="team.id"
                :label="team.name"
                :icon="
                  macro.team_ids.includes(team.id)
                    ? 'i-lucide-check'
                    : 'i-lucide-plus'
                "
                xs
                :color="macro.team_ids.includes(team.id) ? 'blue' : 'slate'"
                :variant="
                  macro.team_ids.includes(team.id) ? 'faded' : 'outline'
                "
                @click="toggleTeam(team.id)"
              />
            </div>
            <span class="mt-2 text-sm font-medium text-n-slate-12">
              {{ t('MACROS.EDITOR.AGENTS_LABEL') }}
            </span>
            <div class="flex flex-wrap gap-2">
              <Button
                v-for="agent in agents"
                :key="agent.id"
                :label="agent.name"
                :icon="
                  macro.user_ids.includes(agent.id)
                    ? 'i-lucide-check'
                    : 'i-lucide-plus'
                "
                xs
                :color="macro.user_ids.includes(agent.id) ? 'blue' : 'slate'"
                :variant="
                  macro.user_ids.includes(agent.id) ? 'faded' : 'outline'
                "
                @click="toggleAgent(agent.id)"
              />
            </div>
            <p v-if="teamsError" class="mb-0 text-xs text-n-ruby-11">
              {{ teamsError }}
            </p>
          </div>
        </div>
      </InfoCard>

      <InfoCard
        :title="t('MACROS.EDITOR.ACTIONS_TITLE')"
        icon="i-lucide-list-checks"
      >
        <template #actions>
          <Button
            :label="t('MACROS.EDITOR.ADD_BTN_TOOLTIP')"
            icon="i-lucide-plus"
            faded
            slate
            xs
            @click="addAction"
          />
        </template>
        <div class="flex flex-col gap-3">
          <p class="mb-0 text-xs text-n-slate-11">
            {{ t('MACROS.EDITOR.ACTIONS_HINT') }}
          </p>
          <p v-if="errors.actions" class="mb-0 text-xs text-n-ruby-11">
            {{ t(`MACROS.ERRORS.${errors.actions}`) }}
          </p>
          <Draggable
            :list="macro.actions"
            animation="200"
            :item-key="actionKey"
            handle=".macro-action-drag-handle"
            class="flex flex-col gap-3"
          >
            <template #item="{ index }">
              <MacroActionCard
                v-model="macro.actions[index]"
                :index="index"
                :error-key="errors[`action_${index}`]"
                :file-name="
                  getFileName(
                    macro.actions[index].action_params[0],
                    macro.actions[index].action_name,
                    files
                  )
                "
                :can-remove="macro.actions.length > 1"
                @reset-action="resetAction(index)"
                @remove="removeAction(index)"
              />
            </template>
          </Draggable>
        </div>
      </InfoCard>
    </div>
  </div>
</template>
