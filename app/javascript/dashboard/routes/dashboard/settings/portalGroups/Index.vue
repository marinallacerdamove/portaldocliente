<script setup>
// PATCH LOCAL (fork) - Grupos de clientes (Configurações), tudo numa tela só.
// Os dados moram no Portal. Lista de grupos; clicar num grupo abre ali mesmo
// os contatos dele (das empresas vinculadas e avulsos) com a situação de cada
// um. Administrador: "Novo grupo" (nome + empresas), "Vincular empresas" e
// "Adicionar contato" (janela com busca e "Selecionar todas"), × no contato
// avulso e lápis pra nome/ativo. Cada alteração grava na hora com a lista
// COMPLETA (PATCH). Agente só vê. O grupo automático "Todos os clientes
// ativos" vem primeiro e nunca edita. Contato novo da empresa entra sozinho;
// inativado para de receber (o Portal calcula).
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import {
  portalGroupsErrorMessage,
  usePortalGroups,
} from 'dashboard/composables/usePortalGroups';
import PortalGroupsAPI from 'dashboard/api/portalGroups';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import PortalGroupActiveBadge from 'dashboard/components-next/PortalGroups/PortalGroupActiveBadge.vue';
import PortalGroupContactsPanel from 'dashboard/components-next/PortalGroups/PortalGroupContactsPanel.vue';
import PortalGroupNameDialog from 'dashboard/components-next/PortalGroups/PortalGroupNameDialog.vue';
import PortalGroupPickerDialog from 'dashboard/components-next/PortalGroups/PortalGroupPickerDialog.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

// Qual janela de escolha está aberta.
const PICKER = {
  CREATE: 'create',
  COMPANIES: 'companies',
  CONTACTS: 'contacts',
};

const { t } = useI18n();
const { isAdmin } = useAdmin();
const { groups, isLoading, hasError, errorMessage, fetchGroups } =
  usePortalGroups();

const expandedId = ref(null);
const details = ref({});
const loadingDetailId = ref(null);
const detailError = ref('');
const savingId = ref(null);

const options = ref(null);
const isLoadingOptions = ref(false);
const optionsError = ref('');

const pickerRef = ref(null);
const pickerMode = ref(PICKER.COMPANIES);
const pickerGroupId = ref(null);
const pickerError = ref('');
const isPickerSaving = ref(false);
const newGroupName = ref('');

const editDialogRef = ref(null);
const editingGroup = ref(null);
const editError = ref('');
const isEditSaving = ref(false);

const canEditGroup = group => isAdmin.value && !group.automatic;

const loadGroups = () => fetchGroups({ all: true });

const fetchDetail = async id => {
  loadingDetailId.value = id;
  detailError.value = '';
  try {
    const { data } = await PortalGroupsAPI.show(id);
    details.value = { ...details.value, [id]: data };
  } catch (error) {
    detailError.value =
      portalGroupsErrorMessage(error) || t('PORTAL_GROUPS.LOAD_ERROR');
  } finally {
    loadingDetailId.value = null;
  }
};

// Sempre busca de novo ao abrir: contato novo da empresa já aparece.
const toggleGroup = id => {
  if (expandedId.value === id) {
    expandedId.value = null;
    return;
  }
  expandedId.value = id;
  fetchDetail(id);
};

// O Portal devolve o detalhe recalculado: atualiza a linha e o que está aberto.
const applyGroup = data => {
  details.value = { ...details.value, [data.id]: data };
  const index = groups.value.findIndex(group => group.id === data.id);
  const summary = {
    id: data.id,
    name: data.name,
    automatic: data.automatic,
    active: data.active,
    empresas_count: data.empresas_count,
    contatos_count: data.contatos_count,
    recipients_count: data.recipients_count,
  };
  if (index === -1) groups.value = [...groups.value, summary];
  else groups.value.splice(index, 1, summary);
};

const fetchOptions = async () => {
  isLoadingOptions.value = true;
  optionsError.value = '';
  try {
    ({ data: options.value } = await PortalGroupsAPI.memberOptions());
  } catch (error) {
    optionsError.value =
      portalGroupsErrorMessage(error) || t('PORTAL_GROUPS.PICKER.ERROR');
  } finally {
    isLoadingOptions.value = false;
  }
};

const empresaItems = computed(() =>
  (options.value?.empresas || []).map(empresa => ({
    id: empresa.id,
    title: empresa.nome,
    subtitle: [
      empresa.cnpj,
      empresa.active ? '' : t('PORTAL_GROUPS.PICKER.INACTIVE_COMPANY'),
    ]
      .filter(Boolean)
      .join(' · '),
    info: t(
      'PORTAL_GROUPS.PICKER.CONTACTS',
      { count: empresa.contatos_count },
      empresa.contatos_count
    ),
  }))
);

const contatoItems = computed(() =>
  (options.value?.contatos || []).map(contato => ({
    id: contato.id,
    title: contato.name,
    subtitle: [contato.phone, contato.email, ...(contato.empresas || [])]
      .filter(Boolean)
      .join(' · '),
    info: '',
  }))
);

const picker = computed(() => {
  const groupName =
    groups.value.find(group => group.id === pickerGroupId.value)?.name || '';
  return {
    [PICKER.CREATE]: {
      title: t('PORTAL_GROUPS.CREATE.TITLE'),
      description: t('PORTAL_GROUPS.CREATE.DESCRIPTION'),
      confirmLabel: t('PORTAL_GROUPS.CREATE.SUBMIT'),
      searchPlaceholder: t('PORTAL_GROUPS.PICKER.SEARCH_COMPANIES'),
      items: empresaItems.value,
    },
    [PICKER.COMPANIES]: {
      title: t('PORTAL_GROUPS.PICKER.COMPANIES_TITLE', { name: groupName }),
      description: t('PORTAL_GROUPS.PICKER.COMPANIES_DESCRIPTION'),
      confirmLabel: t('PORTAL_GROUPS.PICKER.SAVE'),
      searchPlaceholder: t('PORTAL_GROUPS.PICKER.SEARCH_COMPANIES'),
      items: empresaItems.value,
    },
    [PICKER.CONTACTS]: {
      title: t('PORTAL_GROUPS.PICKER.CONTACTS_TITLE', { name: groupName }),
      description: t('PORTAL_GROUPS.PICKER.CONTACTS_DESCRIPTION'),
      confirmLabel: t('PORTAL_GROUPS.PICKER.SAVE'),
      searchPlaceholder: t('PORTAL_GROUPS.PICKER.SEARCH_CONTACTS'),
      items: contatoItems.value,
    },
  }[pickerMode.value];
});

const openPicker = (mode, groupId = null) => {
  pickerMode.value = mode;
  pickerGroupId.value = groupId;
  pickerError.value = '';
  newGroupName.value = '';
  if (!options.value && !isLoadingOptions.value) fetchOptions();
  const detail = details.value[groupId];
  const selected = {
    [PICKER.CREATE]: [],
    [PICKER.COMPANIES]: (detail?.empresas || []).map(empresa => empresa.id),
    [PICKER.CONTACTS]: (detail?.contatos || []).map(contato => contato.id),
  }[mode];
  pickerRef.value?.open(selected);
};

const updateGroup = (id, attributes) =>
  PortalGroupsAPI.update(id, attributes).then(({ data }) => {
    applyGroup(data);
    return data;
  });

// Grupo novo: cria com o nome e, se marcou empresas, já vincula. Se o vínculo
// falhar, a janela passa a ser a de vincular empresas desse grupo (tentar de
// novo não cria outro grupo).
const createGroup = async empresaIds => {
  const { data } = await PortalGroupsAPI.create({
    name: newGroupName.value.trim(),
  });
  applyGroup(data);
  pickerMode.value = PICKER.COMPANIES;
  pickerGroupId.value = data.id;
  if (empresaIds.length) {
    await updateGroup(data.id, { empresa_ids: empresaIds });
  }
  expandedId.value = data.id;
  useAlert(t('PORTAL_GROUPS.CREATE.SUCCESS'));
};

const confirmPicker = async ids => {
  isPickerSaving.value = true;
  pickerError.value = '';
  try {
    if (pickerMode.value === PICKER.CREATE) {
      await createGroup(ids);
    } else {
      const field =
        pickerMode.value === PICKER.COMPANIES ? 'empresa_ids' : 'partner_ids';
      await updateGroup(pickerGroupId.value, { [field]: ids });
      expandedId.value = pickerGroupId.value;
      useAlert(t('PORTAL_GROUPS.SAVE_SUCCESS'));
    }
    pickerRef.value?.close();
  } catch (error) {
    pickerError.value =
      portalGroupsErrorMessage(error) || t('PORTAL_GROUPS.SAVE_ERROR');
  } finally {
    isPickerSaving.value = false;
  }
};

const removeContact = async (group, partnerId) => {
  savingId.value = group.id;
  try {
    const detail = details.value[group.id];
    await updateGroup(group.id, {
      partner_ids: detail.contatos
        .map(contato => contato.id)
        .filter(id => id !== partnerId),
    });
    useAlert(t('PORTAL_GROUPS.PANEL.REMOVED'));
  } catch (error) {
    useAlert(portalGroupsErrorMessage(error) || t('PORTAL_GROUPS.SAVE_ERROR'));
  } finally {
    savingId.value = null;
  }
};

const openEdit = group => {
  editingGroup.value = group;
  editError.value = '';
  editDialogRef.value?.open(group);
};

const saveEdit = async attributes => {
  isEditSaving.value = true;
  editError.value = '';
  try {
    await updateGroup(editingGroup.value.id, attributes);
    editDialogRef.value?.close();
    useAlert(t('PORTAL_GROUPS.SAVE_SUCCESS'));
  } catch (error) {
    editError.value =
      portalGroupsErrorMessage(error) || t('PORTAL_GROUPS.SAVE_ERROR');
  } finally {
    isEditSaving.value = false;
  }
};

onMounted(loadGroups);
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
            icon="i-lucide-plus"
            size="sm"
            @click="openPicker(PICKER.CREATE)"
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
          @click="loadGroups"
        />
      </div>
    </template>

    <template #body>
      <div
        v-if="!hasError"
        class="overflow-hidden border rounded-xl border-n-weak bg-n-solid-1"
      >
        <div
          class="grid grid-cols-[1rem_minmax(0,1fr)_6rem_6rem_8rem_6rem_2rem] items-center gap-x-4 px-4 py-2.5 text-xs font-medium border-b text-n-slate-11 border-n-weak"
        >
          <span />
          <span>{{ t('PORTAL_GROUPS.TABLE.NAME') }}</span>
          <span>{{ t('PORTAL_GROUPS.TABLE.COMPANIES') }}</span>
          <span>{{ t('PORTAL_GROUPS.TABLE.CONTACTS') }}</span>
          <span>{{ t('PORTAL_GROUPS.TABLE.RECIPIENTS') }}</span>
          <span>{{ t('PORTAL_GROUPS.TABLE.STATUS') }}</span>
          <span />
        </div>

        <div class="flex flex-col divide-y divide-n-weak">
          <div v-for="group in groups" :key="group.id">
            <div
              role="button"
              tabindex="0"
              :aria-expanded="expandedId === group.id"
              class="grid grid-cols-[1rem_minmax(0,1fr)_6rem_6rem_8rem_6rem_2rem] items-center gap-x-4 px-4 py-3 text-sm cursor-pointer min-h-14 hover:bg-n-alpha-1"
              :class="{ 'bg-n-alpha-1': expandedId === group.id }"
              @click="toggleGroup(group.id)"
              @keydown.enter="toggleGroup(group.id)"
            >
              <span
                class="i-lucide-chevron-right size-4 text-n-slate-10 transition-transform"
                :class="{ 'rotate-90': expandedId === group.id }"
              />
              <span class="flex items-center min-w-0 gap-2">
                <span class="font-medium truncate text-n-slate-12">
                  {{ group.name }}
                </span>
                <span
                  v-if="group.automatic"
                  class="px-1.5 py-0.5 text-xs rounded-md shrink-0 bg-n-blue-3 text-n-blue-11"
                >
                  {{ t('PORTAL_GROUPS.AUTOMATIC') }}
                </span>
              </span>
              <span class="text-n-slate-11">{{ group.empresas_count }}</span>
              <span class="text-n-slate-11">{{ group.contatos_count }}</span>
              <span class="font-medium text-n-slate-12">
                {{ group.recipients_count }}
              </span>
              <span><PortalGroupActiveBadge :active="group.active" /></span>
              <span class="flex justify-end">
                <Button
                  v-if="canEditGroup(group)"
                  :title="t('PORTAL_GROUPS.EDIT_TOOLTIP')"
                  icon="i-woot-edit-pen"
                  variant="ghost"
                  color="slate"
                  size="xs"
                  @click.stop="openEdit(group)"
                />
              </span>
            </div>

            <template v-if="expandedId === group.id">
              <div
                v-if="loadingDetailId === group.id"
                class="flex items-center gap-2 py-4 text-sm ps-12 text-n-slate-11 bg-n-alpha-1"
              >
                <Spinner :size="16" />
                {{ t('PORTAL_GROUPS.LOADING_GROUP') }}
              </div>
              <div
                v-else-if="!details[group.id]"
                class="flex items-center gap-3 py-4 ps-12 bg-n-alpha-1"
              >
                <span class="text-sm text-n-ruby-11">{{ detailError }}</span>
                <Button
                  :label="t('PORTAL_GROUPS.RETRY')"
                  variant="faded"
                  color="slate"
                  size="xs"
                  @click="fetchDetail(group.id)"
                />
              </div>
              <PortalGroupContactsPanel
                v-else
                :group="details[group.id]"
                :can-edit="canEditGroup(group)"
                :busy="savingId === group.id"
                @link-companies="openPicker(PICKER.COMPANIES, group.id)"
                @add-contacts="openPicker(PICKER.CONTACTS, group.id)"
                @remove-contact="removeContact(group, $event)"
              />
            </template>
          </div>
        </div>
      </div>
    </template>

    <PortalGroupPickerDialog
      ref="pickerRef"
      :title="picker.title"
      :description="picker.description"
      :confirm-label="picker.confirmLabel"
      :search-placeholder="picker.searchPlaceholder"
      :items="picker.items"
      :is-loading-items="isLoadingOptions"
      :items-error="optionsError"
      :error-message="pickerError"
      :is-loading="isPickerSaving"
      :can-confirm="pickerMode !== PICKER.CREATE || !!newGroupName.trim()"
      @confirm="confirmPicker"
      @retry="fetchOptions"
    >
      <template v-if="pickerMode === PICKER.CREATE" #top>
        <Input
          v-model="newGroupName"
          :label="t('PORTAL_GROUPS.NAME_DIALOG.LABEL')"
          :placeholder="t('PORTAL_GROUPS.NAME_DIALOG.PLACEHOLDER')"
          :disabled="isPickerSaving"
        />
      </template>
    </PortalGroupPickerDialog>

    <PortalGroupNameDialog
      ref="editDialogRef"
      :error-message="editError"
      :is-loading="isEditSaving"
      @submit="saveEdit"
    />
  </SettingsLayout>
</template>
