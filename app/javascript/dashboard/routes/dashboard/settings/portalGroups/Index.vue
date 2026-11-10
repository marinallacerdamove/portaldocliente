<script setup>
// PATCH LOCAL (fork) - lista de Grupos de clientes (Configurações), no padrão
// da lista dos cadastros de atendimento. Os dados moram no Portal; o grupo
// automático "Todos os clientes ativos" vem primeiro e não edita. Mostra
// também os inativos (com selo). Só administrador cria; agente vê e abre a
// ficha em modo leitura.
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import {
  portalGroupsErrorMessage,
  usePortalGroups,
} from 'dashboard/composables/usePortalGroups';
import PortalGroupsAPI from 'dashboard/api/portalGroups';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import PortalGroupActiveBadge from 'dashboard/components-next/PortalGroups/PortalGroupActiveBadge.vue';
import PortalGroupNameDialog from 'dashboard/components-next/PortalGroups/PortalGroupNameDialog.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t } = useI18n();
const router = useRouter();
const { isAdmin } = useAdmin();
const { groups, isLoading, hasError, errorMessage, fetchGroups } =
  usePortalGroups();

const createDialogRef = ref(null);
const isCreating = ref(false);
const nameError = ref('');

const tableHeaders = computed(() => [
  t('PORTAL_GROUPS.TABLE.NAME'),
  t('PORTAL_GROUPS.TABLE.COMPANIES'),
  t('PORTAL_GROUPS.TABLE.CONTACTS'),
  t('PORTAL_GROUPS.TABLE.RECIPIENTS'),
  t('PORTAL_GROUPS.TABLE.STATUS'),
  t('PORTAL_GROUPS.TABLE.ACTIONS'),
]);

const goToGroup = id =>
  router.push({ name: 'portal_groups_show', params: { groupId: id } });

const openCreateDialog = () => {
  nameError.value = '';
  createDialogRef.value?.open();
};

// Grupo novo nasce vazio: abre a ficha pra já escolher as empresas e contatos.
const createGroup = async name => {
  isCreating.value = true;
  nameError.value = '';
  try {
    const { data } = await PortalGroupsAPI.create({ name });
    useAlert(t('PORTAL_GROUPS.CREATE.SUCCESS'));
    createDialogRef.value?.close();
    goToGroup(data.id);
  } catch (error) {
    nameError.value =
      portalGroupsErrorMessage(error) || t('PORTAL_GROUPS.CREATE.ERROR');
  } finally {
    isCreating.value = false;
  }
};

onMounted(() => fetchGroups({ all: true }));
</script>

<template>
  <SettingsLayout
    :no-records-message="t('PORTAL_GROUPS.EMPTY')"
    :no-records-found="!hasError && !groups.length"
    :is-loading="isLoading"
    :loading-message="t('PORTAL_GROUPS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('PORTAL_GROUPS.TITLE')"
        :description="t('PORTAL_GROUPS.DESCRIPTION')"
      >
        <template v-if="isAdmin" #actions>
          <Button
            :label="t('PORTAL_GROUPS.NEW')"
            size="sm"
            @click="openCreateDialog"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #preBody>
      <div
        v-if="hasError && !isLoading"
        class="flex flex-col items-start gap-3"
      >
        <p class="mb-0 text-sm text-n-ruby-11">
          {{ errorMessage || t('PORTAL_GROUPS.LOAD_ERROR') }}
        </p>
        <Button
          :label="t('PORTAL_GROUPS.RETRY')"
          variant="faded"
          color="slate"
          size="sm"
          @click="fetchGroups({ all: true })"
        />
      </div>
    </template>

    <template #body>
      <BaseTable v-if="!hasError" :headers="tableHeaders" :items="groups">
        <template #row="{ items }">
          <BaseTableRow v-for="group in items" :key="group.id" :item="group">
            <BaseTableCell class="max-w-0 min-w-0 w-2/5">
              <div class="flex items-center min-w-0 gap-2">
                <span class="block truncate text-body-main text-n-slate-12">
                  {{ group.name }}
                </span>
                <span
                  v-if="group.automatic"
                  class="px-1.5 py-0.5 text-xs rounded-md shrink-0 bg-n-blue-3 text-n-blue-11"
                >
                  {{ t('PORTAL_GROUPS.AUTOMATIC') }}
                </span>
              </div>
            </BaseTableCell>
            <BaseTableCell>{{ group.empresas_count }}</BaseTableCell>
            <BaseTableCell>{{ group.contatos_count }}</BaseTableCell>
            <BaseTableCell>
              <span class="font-medium text-n-slate-12">
                {{ group.recipients_count }}
              </span>
            </BaseTableCell>
            <BaseTableCell class="w-28">
              <PortalGroupActiveBadge :active="group.active" />
            </BaseTableCell>
            <BaseTableCell align="end" class="w-20">
              <Button
                :title="
                  isAdmin && !group.automatic
                    ? t('PORTAL_GROUPS.EDIT_TOOLTIP')
                    : t('PORTAL_GROUPS.VIEW_TOOLTIP')
                "
                :icon="
                  isAdmin && !group.automatic
                    ? 'i-woot-edit-pen'
                    : 'i-lucide-eye'
                "
                slate
                sm
                @click="goToGroup(group.id)"
              />
            </BaseTableCell>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <PortalGroupNameDialog
      ref="createDialogRef"
      :title="t('PORTAL_GROUPS.CREATE.TITLE')"
      :confirm-label="t('PORTAL_GROUPS.CREATE.SUBMIT')"
      :error-message="nameError"
      :is-loading="isCreating"
      @submit="createGroup"
    />
  </SettingsLayout>
</template>
