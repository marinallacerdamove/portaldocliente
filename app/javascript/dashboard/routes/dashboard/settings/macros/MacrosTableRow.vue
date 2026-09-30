<script setup>
import { computed } from 'vue';
import Avatar from 'next/avatar/Avatar.vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';

import Button from 'dashboard/components-next/button/Button.vue';
import { BaseTableRow, BaseTableCell } from 'dashboard/components-next/table';

const props = defineProps({
  macro: {
    type: Object,
    required: true,
  },
  canManagePublicMacros: {
    type: Boolean,
    default: true,
  },
});
defineEmits(['delete']);
const { t } = useI18n();

const createdByName = computed(() => {
  const createdBy = props.macro.created_by;
  return createdBy.available_name ?? createdBy.email ?? '';
});

const updatedByName = computed(() => {
  const updatedBy = props.macro.updated_by;
  return updatedBy.available_name ?? updatedBy.email ?? '';
});

// PATCH LOCAL (fork) - compartilhamento por equipe mostra quais.
const teams = useMapGetter('teams/getTeams');

const agents = useMapGetter('agents/getAgents');

const visibilityLabel = computed(() => {
  const {
    visibility,
    team_ids: teamIds = [],
    user_ids: userIds = [],
  } = props.macro;
  if (visibility === 'team') {
    const names = [
      ...teams.value.filter(team => teamIds.includes(team.id)),
      ...agents.value.filter(agent => userIds.includes(agent.id)),
    ]
      .map(item => item.name)
      .join(', ');
    return t('MACROS.LIST_EXTRA.TEAMS', { teams: names });
  }
  const i18nKey =
    visibility === 'global'
      ? 'MACROS.EDITOR.VISIBILITY.GLOBAL.LABEL'
      : 'MACROS.EDITOR.VISIBILITY.PERSONAL.LABEL';
  return t(i18nKey);
});

const canManageMacro = computed(
  () => props.canManagePublicMacros || props.macro.visibility === 'personal'
);

const editTooltip = computed(() =>
  canManageMacro.value ? t('MACROS.EDIT.TOOLTIP') : t('MACROS.VIEW.TOOLTIP')
);
</script>

<template>
  <BaseTableRow :item="macro">
    <template #default>
      <BaseTableCell class="max-w-0 min-w-0 w-2/5">
        <span class="text-body-main text-n-slate-12 truncate block">
          {{ macro.name }}
        </span>
      </BaseTableCell>

      <BaseTableCell class="max-w-0 w-[15%]">
        <span class="block truncate text-body-main text-n-slate-11">
          {{ macro.group_name || $t('MACROS.LIST_EXTRA.NO_GROUP') }}
        </span>
      </BaseTableCell>

      <BaseTableCell class="max-w-0">
        <div v-if="macro.created_by" class="flex items-center gap-2 min-w-0">
          <Avatar
            :name="createdByName"
            :size="24"
            rounded-full
            class="flex-shrink-0"
          />
          <span class="text-body-main text-n-slate-12 truncate">
            {{ createdByName }}
          </span>
        </div>
        <span v-else class="text-body-main text-n-slate-11">--</span>
      </BaseTableCell>

      <BaseTableCell class="max-w-0">
        <div v-if="macro.updated_by" class="flex items-center gap-2 min-w-0">
          <Avatar
            :name="updatedByName"
            :size="24"
            rounded-full
            class="flex-shrink-0"
          />
          <span class="text-body-main text-n-slate-12 truncate">
            {{ updatedByName }}
          </span>
        </div>
        <span v-else class="text-body-main text-n-slate-11">--</span>
      </BaseTableCell>

      <BaseTableCell class="max-w-0">
        <span class="block truncate text-body-main text-n-slate-12">
          {{ visibilityLabel }}
        </span>
      </BaseTableCell>

      <BaseTableCell align="end" class="w-32">
        <div class="flex gap-3 justify-end flex-shrink-0">
          <router-link
            :to="{ name: 'macros_edit', params: { macroId: macro.id } }"
          >
            <Button
              v-tooltip.top="editTooltip"
              icon="i-woot-edit-pen"
              slate
              sm
            />
          </router-link>
          <router-link :to="{ name: 'macros_new', query: { clone: macro.id } }">
            <Button
              v-tooltip.top="$t('MACROS.CLONE.TOOLTIP')"
              icon="i-lucide-copy"
              slate
              sm
            />
          </router-link>
          <Button
            v-if="canManageMacro"
            v-tooltip.top="$t('MACROS.DELETE.TOOLTIP')"
            icon="i-woot-bin"
            slate
            sm
            class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
            @click="$emit('delete')"
          />
        </div>
      </BaseTableCell>
    </template>
  </BaseTableRow>
</template>
