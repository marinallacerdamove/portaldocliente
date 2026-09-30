<script setup>
import { ref, computed, watch, provide } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import MacroForm from './MacroForm.vue';
import { MACRO_ACTION_TYPES } from './constants';
import { useAlert } from 'dashboard/composables';
import actionQueryGenerator from 'dashboard/helper/actionQueryGenerator.js';
import { getActionIcon } from 'dashboard/helper/automationHelper';
import { useMacros } from 'dashboard/composables/useMacros';
import { useAdmin } from 'dashboard/composables/useAdmin';

const store = useStore();
const getters = useStoreGetters();

const route = useRoute();
const router = useRouter();

const { t } = useI18n();

const { getMacroDropdownValues } = useMacros();
const { isAdmin } = useAdmin();

const macro = ref(null);
const mode = ref('CREATE');

const macroActionTypes = computed(() => {
  return MACRO_ACTION_TYPES.map(type => ({
    ...type,
    label: t(`MACROS.ACTIONS.${type.label}`),
    icon: getActionIcon(type.key),
  }));
});

provide('macroActionTypes', macroActionTypes);

const uiFlags = computed(() => getters['macros/getUIFlags'].value);
const macroId = computed(() => route.params.macroId);
// PATCH LOCAL (fork) - macro de equipe também só o administrador altera.
const isPublicMacroReadOnly = computed(
  () => ['global', 'team'].includes(macro.value?.visibility) && !isAdmin.value
);
const isSaving = ref(false);
const macroGroups = computed(() =>
  [
    ...new Set(
      getters['macros/getMacros'].value
        .map(item => item.group_name)
        .filter(Boolean)
    ),
  ].sort((a, b) => a.localeCompare(b))
);

const fetchDropdownData = () =>
  Promise.all([
    store.dispatch('agents/get'),
    store.dispatch('teams/get'),
    store.dispatch('labels/get'),
    store.dispatch('macros/get'),
    store.dispatch('attributes/get'),
  ]);

const formatMacro = macroData => {
  const formattedActions = macroData.actions.map(action => {
    let actionParams = [];
    if (action.action_params.length) {
      const inputType = macroActionTypes.value.find(
        item => item.key === action.action_name
      )?.inputType;
      if (inputType === 'multi_select' || inputType === 'search_select') {
        actionParams = getMacroDropdownValues(action.action_name).filter(item =>
          [...action.action_params].includes(item.id)
        );
      } else actionParams = [...action.action_params];
    }
    return {
      ...action,
      action_params: actionParams,
    };
  });
  return {
    ...macroData,
    actions: formattedActions,
  };
};

const manifestMacro = async () => {
  await Promise.all([
    fetchDropdownData(),
    store.dispatch('macros/getSingleMacro', macroId.value),
  ]);
  const singleMacro = store.getters['macros/getMacro'](macroId.value);
  macro.value = formatMacro(singleMacro);
};

// PATCH LOCAL (fork) - "Clonar": abre uma macro nova já preenchida com a
// original. Anexo fica de fora (o arquivo é da macro original).
const cloneMacro = async sourceId => {
  mode.value = 'CREATE';
  await Promise.all([
    fetchDropdownData(),
    store.dispatch('macros/getSingleMacro', sourceId),
  ]);
  const source = formatMacro(store.getters['macros/getMacro'](sourceId));
  const actions = source.actions.filter(
    action => action.action_name !== 'send_attachment'
  );
  macro.value = {
    name: t('MACROS.CLONE.NAME', { name: source.name }),
    group_name: source.group_name || '',
    team_ids: source.team_ids || [],
    user_ids: source.user_ids || [],
    visibility: isAdmin.value ? source.visibility : 'personal',
    actions: actions.length
      ? actions
      : [{ action_name: 'fill_reply', action_params: [] }],
  };
};

const fetchMacro = () => {
  mode.value = 'EDIT';
  manifestMacro();
};

const initNewMacro = () => {
  mode.value = 'CREATE';
  macro.value = {
    name: '',
    group_name: '',
    team_ids: [],
    user_ids: [],
    actions: [
      {
        action_name: 'fill_reply',
        action_params: [],
      },
    ],
    visibility: isAdmin.value ? 'global' : 'personal',
  };
};

watch(
  () => route,
  () => {
    if (route.params.macroId) {
      fetchMacro();
    } else if (route.query.clone) {
      cloneMacro(route.query.clone);
    } else {
      fetchDropdownData();
      initNewMacro();
    }
  },
  { immediate: true, deep: true }
);

const saveMacro = async macroData => {
  if (isPublicMacroReadOnly.value) return;

  isSaving.value = true;
  try {
    const action = mode.value === 'EDIT' ? 'macros/update' : 'macros/create';
    const successMessage =
      mode.value === 'EDIT'
        ? t('MACROS.EDIT.API.SUCCESS_MESSAGE')
        : t('MACROS.ADD.API.SUCCESS_MESSAGE');
    let serializedMacro = JSON.parse(JSON.stringify(macroData));
    serializedMacro.actions = actionQueryGenerator(serializedMacro.actions);
    await store.dispatch(action, serializedMacro);
    useAlert(successMessage);
    router.push({ name: 'macros_wrapper' });
  } catch (error) {
    useAlert(t('MACROS.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const cancel = () => router.push({ name: 'macros_wrapper' });
</script>

<template>
  <div class="flex flex-col w-full h-full !px-6 overflow-y-auto">
    <woot-loading-state
      v-if="uiFlags.isFetchingItem"
      :message="t('MACROS.EDITOR.LOADING')"
    />
    <MacroForm
      v-if="macro && !uiFlags.isFetchingItem"
      :macro-data="macro"
      :can-manage-public-macros="isAdmin"
      :read-only="isPublicMacroReadOnly"
      :is-edit="mode === 'EDIT'"
      :groups="macroGroups"
      :is-saving="isSaving"
      @submit="saveMacro"
      @cancel="cancel"
    />
  </div>
</template>
