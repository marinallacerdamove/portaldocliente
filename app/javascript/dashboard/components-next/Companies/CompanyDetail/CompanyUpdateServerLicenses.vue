<script setup>
// Licenças do Albatross da empresa: uma linha por usuário com os módulos dele,
// busca, filtros (status e módulo vindo do quadro de totais), agrupamento por
// código, adicionar vários de uma vez e exportar CSV. Sem exclusão: a licença
// sai de uso desligando "Ativa" (e deixa de contar nos totais, somados no
// Portal).
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { downloadCsvFile } from 'dashboard/helper/downloadHelper';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import CompanyUpdateServerBulkLicenses from './CompanyUpdateServerBulkLicenses.vue';
import CompanyUpdateServerModules from './CompanyUpdateServerModules.vue';
import CompanyUpdateServerSummary from './CompanyUpdateServerSummary.vue';
import UpdateServerEmpty from './UpdateServerEmpty.vue';
import UpdateServerModuleChip from './UpdateServerModuleChip.vue';
import UpdateServerSortableTh from './UpdateServerSortableTh.vue';
import UpdateServerStatusSwitch from './UpdateServerStatusSwitch.vue';
import UpdateServerToolbar from './UpdateServerToolbar.vue';
import { useUpdateServerList } from './useUpdateServerList';
import {
  groupByCode,
  hasActiveUser,
  hasModule,
  modulesOfLicense,
  toCsv,
} from './updateServerHelpers';

const props = defineProps({
  licenses: { type: Array, default: () => [] },
  summary: { type: Object, default: null },
  modules: { type: Array, default: () => [] },
  isSaving: { type: Boolean, default: false },
  save: { type: Function, required: true },
  saveEach: { type: Function, default: null },
  saveModule: { type: Function, default: null },
  reorderModules: { type: Function, default: null },
});
const emit = defineEmits(['busyChange']);

// Módulo escolhido no quadro de totais (código); vazio = sem filtro.
const moduleFilter = defineModel('moduleFilter', { type: String, default: '' });

const { t } = useI18n();
const i18nKey = suffix => `COMPANIES.DETAIL.UPDATE_SERVER.${suffix}`;
const CSV_FILE_NAME = 'update-server-licencas.csv';
const SPAN_COLUMNS = 6;

const list = useUpdateServerList(
  () =>
    props.licenses.filter(
      license =>
        !moduleFilter.value ||
        hasModule(license, props.modules, moduleFilter.value)
    ),
  {
    searchKeys: ['user_name', 'code', 'license_type', 'combination'],
    sortKey: 'user_name',
  }
);

const emptyDraft = () => ({
  user_name: '',
  code: '',
  license_type: '',
  active: true,
  license_module_ids: [],
});

const editingId = ref(null); // 'new' ou o id da licença
const draft = ref(emptyDraft());
const bulkOpen = ref(false);
const modulesOpen = ref(false);
const grouped = ref(false);
const togglingId = ref(null);

// Módulo inativo só aparece se a licença em edição ainda o tem.
const selectableModules = computed(() =>
  props.modules.filter(
    mod => mod.active || draft.value.license_module_ids.includes(mod.id)
  )
);

// O container só recarrega sozinho quando nada está aberto aqui.
watch(
  () => editingId.value !== null || bulkOpen.value || modulesOpen.value,
  busy => emit('busyChange', busy)
);

// Igual ao Portal: "todos" quando nada está filtrado, senão "N de M".
const showingText = computed(() => {
  const shown = list.visible.value.length;
  const total = props.licenses.length;
  if (shown === total) return t(i18nKey('LICENSES.SHOWING_ALL'));
  return t(i18nKey('LICENSES.SHOWING_COUNT'), { shown, total }, shown);
});

const groups = computed(() => groupByCode(list.visible.value));

const duplicateUser = computed(() =>
  hasActiveUser(
    props.licenses,
    draft.value.user_name,
    editingId.value === 'new' ? null : editingId.value
  )
);

const startNew = () => {
  draft.value = emptyDraft();
  editingId.value = 'new';
  bulkOpen.value = false;
  modulesOpen.value = false;
};

const startEdit = license => {
  draft.value = {
    ...emptyDraft(),
    ...license,
    license_module_ids: [...license.license_module_ids],
  };
  editingId.value = license.id;
  bulkOpen.value = false;
  modulesOpen.value = false;
};

const startBulk = () => {
  editingId.value = null;
  modulesOpen.value = false;
  bulkOpen.value = true;
};

const startModules = () => {
  editingId.value = null;
  bulkOpen.value = false;
  modulesOpen.value = true;
};

const cancel = () => {
  editingId.value = null;
};

const isModuleChecked = id => draft.value.license_module_ids.includes(id);

const toggleModule = (id, checked) => {
  const others = draft.value.license_module_ids.filter(item => item !== id);
  draft.value.license_module_ids = checked ? [...others, id] : others;
};

const submit = async () => {
  const { user_name, code, license_type, active, license_module_ids } =
    draft.value;
  const licenseId = editingId.value === 'new' ? null : editingId.value;
  const saved = await props.save(licenseId, {
    user_name,
    code,
    license_type,
    active,
    license_module_ids,
  });
  if (saved) editingId.value = null;
};

// Ativar/desativar na linha: só o campo "active" vai (módulos não mudam).
const toggleActive = async (license, active) => {
  togglingId.value = license.id;
  await props.save(license.id, { active });
  togglingId.value = null;
};

const exportCsv = () => {
  const columns = [
    {
      header: t(i18nKey('LICENSES.FIELDS.user_name')),
      value: item => item.user_name,
    },
    { header: t(i18nKey('LICENSES.FIELDS.code')), value: item => item.code },
    {
      header: t(i18nKey('LICENSES.FIELDS.license_type')),
      value: item => item.license_type,
    },
    { header: t(i18nKey('LICENSES.MODULES')), value: item => item.combination },
    {
      header: t(i18nKey('ACTIVE')),
      value: item => (item.active ? t(i18nKey('YES')) : t(i18nKey('NO'))),
    },
  ];
  downloadCsvFile(CSV_FILE_NAME, toCsv(list.visible.value, columns));
};
</script>

<template>
  <InfoCard :title="t(i18nKey('LICENSES.TITLE'))" icon="i-lucide-key-round">
    <template #actions>
      <div
        v-if="editingId === null && !bulkOpen && !modulesOpen"
        class="flex items-center gap-1"
      >
        <Button
          v-if="saveModule"
          :label="t(i18nKey('LICENSES.MODULES_BUTTON'))"
          icon="i-lucide-layout-list"
          ghost
          slate
          xs
          @click="startModules"
        />
        <Button
          v-if="saveEach && licenses.length"
          :label="t(i18nKey('LICENSES.ADD_BULK'))"
          icon="i-lucide-users"
          ghost
          slate
          xs
          @click="startBulk"
        />
        <Button
          v-if="licenses.length"
          :label="t(i18nKey('LICENSES.ADD'))"
          icon="i-lucide-plus"
          ghost
          slate
          xs
          @click="startNew"
        />
      </div>
      <span v-else />
    </template>

    <p class="mt-0 mb-4 text-xs text-n-slate-11">
      {{ t(i18nKey('LICENSES.DESCRIPTION')) }}
    </p>

    <CompanyUpdateServerModules
      v-if="modulesOpen && saveModule"
      :modules="modules"
      :is-busy="isSaving"
      :save-module="saveModule"
      :reorder-modules="reorderModules"
      @close="modulesOpen = false"
    />

    <CompanyUpdateServerBulkLicenses
      v-if="bulkOpen"
      :modules="modules"
      :licenses="licenses"
      :save-each="saveEach"
      @close="bulkOpen = false"
    />

    <div
      v-if="editingId !== null"
      class="flex flex-col gap-4 p-4 mb-4 border rounded-lg border-n-weak bg-n-alpha-1"
    >
      <p class="my-0 text-sm font-medium text-n-slate-12">
        {{
          t(
            i18nKey(
              editingId === 'new' ? 'LICENSES.FORM_NEW' : 'LICENSES.FORM_EDIT'
            )
          )
        }}
      </p>
      <fieldset class="flex flex-col gap-3 p-0 m-0 border-0">
        <legend
          class="p-0 mb-2 text-xs font-semibold uppercase text-n-slate-10"
        >
          {{ t(i18nKey('LICENSES.SECTIONS.USER')) }}
        </legend>
        <Input
          v-model="draft.user_name"
          :label="t(i18nKey('LICENSES.FIELDS.user_name'))"
          :placeholder="t(i18nKey('LICENSES.PLACEHOLDERS.user_name'))"
          :disabled="isSaving"
          custom-input-class="h-8 !pt-1 !pb-1"
        />
        <p
          v-if="duplicateUser"
          class="my-0 text-xs text-n-amber-11"
          role="status"
        >
          {{ t(i18nKey('LICENSES.DUPLICATE_USER')) }}
        </p>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <Input
            v-model="draft.code"
            :label="t(i18nKey('LICENSES.FIELDS.code'))"
            :placeholder="t(i18nKey('LICENSES.PLACEHOLDERS.code'))"
            :message="t(i18nKey('LICENSES.HELP.code'))"
            :disabled="isSaving"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
          <Input
            v-model="draft.license_type"
            :label="t(i18nKey('LICENSES.FIELDS.license_type'))"
            :placeholder="t(i18nKey('LICENSES.PLACEHOLDERS.license_type'))"
            :message="t(i18nKey('LICENSES.HELP.license_type'))"
            :disabled="isSaving"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
        </div>
      </fieldset>
      <fieldset class="flex flex-col gap-2 p-0 m-0 border-0">
        <legend
          class="p-0 mb-2 text-xs font-semibold uppercase text-n-slate-10"
        >
          {{ t(i18nKey('LICENSES.MODULES')) }}
        </legend>
        <div class="flex flex-wrap gap-x-4 gap-y-2">
          <label
            v-for="mod in selectableModules"
            :key="mod.id"
            class="flex items-center gap-2 text-sm text-n-slate-12"
          >
            <Checkbox
              :model-value="isModuleChecked(mod.id)"
              :disabled="isSaving"
              @update:model-value="toggleModule(mod.id, $event)"
            />
            <UpdateServerModuleChip
              :code="mod.code"
              :name="mod.name"
              :inactive="!mod.active"
            />
          </label>
        </div>
        <p class="my-0 text-xs text-n-slate-10">
          {{ t(i18nKey('LICENSES.HELP.modules')) }}
        </p>
      </fieldset>
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <Checkbox v-model="draft.active" :disabled="isSaving" />
        {{ t(i18nKey('ACTIVE')) }}
      </label>
      <div class="flex items-center justify-end gap-2">
        <Button :label="t(i18nKey('CANCEL'))" ghost slate xs @click="cancel" />
        <Button
          :label="isSaving ? t(i18nKey('SAVING')) : t(i18nKey('SAVE'))"
          :disabled="
            isSaving ||
            !draft.user_name.trim() ||
            !draft.license_module_ids.length
          "
          xs
          @click="submit"
        />
      </div>
    </div>

    <UpdateServerEmpty
      v-if="!licenses.length"
      icon="i-lucide-key-round"
      :title="t(i18nKey('LICENSES.EMPTY_TITLE'))"
      :description="t(i18nKey('LICENSES.EMPTY'))"
    >
      <Button
        v-if="editingId === null && !bulkOpen && !modulesOpen"
        :label="t(i18nKey('LICENSES.EMPTY_CTA'))"
        icon="i-lucide-plus"
        xs
        @click="startNew"
      />
    </UpdateServerEmpty>

    <div
      v-else
      class="grid grid-cols-1 gap-4 xl:grid-cols-[17.5rem_minmax(0,1fr)]"
    >
      <CompanyUpdateServerSummary
        :summary="summary"
        :selected="moduleFilter"
        @select="moduleFilter = $event"
      />
      <div class="min-w-0">
        <UpdateServerToolbar
          v-model:search="list.search.value"
          v-model:status="list.status.value"
          :search-placeholder="t(i18nKey('LICENSES.SEARCH'))"
          :counts="list.counts.value"
          :shown="list.visible.value.length"
          :total="licenses.length"
        >
          <template #actions>
            <label class="flex items-center gap-2 text-xs text-n-slate-11">
              <Checkbox v-model="grouped" />
              {{ t(i18nKey('LICENSES.GROUP_BY_CODE')) }}
            </label>
            <Button
              :label="t(i18nKey('EXPORT_CSV'))"
              icon="i-lucide-download"
              ghost
              slate
              xs
              :disabled="!list.visible.value.length"
              @click="exportCsv"
            />
          </template>
        </UpdateServerToolbar>

        <div class="flex items-center gap-2 mb-3 min-h-6">
          <template v-if="moduleFilter">
            <span class="text-xs text-n-slate-11">
              {{ t(i18nKey('LICENSES.MODULE_FILTER')) }}
            </span>
            <button
              type="button"
              class="inline-flex items-center gap-1 pr-1.5"
              :aria-label="t(i18nKey('LICENSES.CLEAR_MODULE_FILTER'))"
              @click="moduleFilter = ''"
            >
              <UpdateServerModuleChip :code="moduleFilter" />
              <span class="i-lucide-x size-3.5 text-n-slate-10" />
            </button>
          </template>
          <span
            v-else
            class="text-xs tabular-nums text-n-slate-11"
            data-testid="license-showing"
          >
            {{ showingText }}
          </span>
        </div>

        <UpdateServerEmpty
          v-if="!list.visible.value.length"
          icon="i-lucide-search-x"
          :title="t(i18nKey('NO_RESULTS_TITLE'))"
          :description="t(i18nKey('NO_RESULTS'))"
        >
          <Button
            :label="t(i18nKey('CLEAR_FILTERS'))"
            ghost
            slate
            xs
            @click="
              list.clearFilters();
              moduleFilter = '';
            "
          />
        </UpdateServerEmpty>
        <div
          v-else
          class="overflow-auto border rounded-lg max-h-[32rem] border-n-weak"
        >
          <table
            class="w-full text-sm text-left border-separate border-spacing-0"
          >
            <thead>
              <tr>
                <UpdateServerSortableTh
                  :label="t(i18nKey('LICENSES.FIELDS.user_name'))"
                  sort-key="user_name"
                  :active-key="list.sortBy.value"
                  :direction="list.sortDirection.value"
                  sticky
                  @sort="list.toggleSort"
                />
                <UpdateServerSortableTh
                  :label="t(i18nKey('LICENSES.COLUMNS.code'))"
                  :title="t(i18nKey('LICENSES.FIELDS.code'))"
                  sort-key="code"
                  :active-key="list.sortBy.value"
                  :direction="list.sortDirection.value"
                  @sort="list.toggleSort"
                />
                <UpdateServerSortableTh
                  :label="t(i18nKey('LICENSES.FIELDS.license_type'))"
                  sort-key="license_type"
                  :active-key="list.sortBy.value"
                  :direction="list.sortDirection.value"
                  @sort="list.toggleSort"
                />
                <UpdateServerSortableTh
                  :label="t(i18nKey('LICENSES.MODULES'))"
                />
                <UpdateServerSortableTh
                  :label="t(i18nKey('ACTIVE'))"
                  sort-key="active"
                  :active-key="list.sortBy.value"
                  :direction="list.sortDirection.value"
                  @sort="list.toggleSort"
                />
                <th class="sticky top-0 z-10 w-10 bg-n-solid-2" />
              </tr>
            </thead>
            <tbody
              v-for="group in grouped
                ? groups
                : [{ code: null, items: list.visible.value }]"
              :key="group.code ?? 'all'"
            >
              <tr v-if="grouped">
                <td
                  :colspan="SPAN_COLUMNS"
                  class="px-3 py-2 text-xs font-semibold border-t border-n-weak bg-n-alpha-1 text-n-slate-11"
                >
                  {{
                    group.code
                      ? t(i18nKey('LICENSES.GROUP_TITLE'), { code: group.code })
                      : t(i18nKey('LICENSES.NO_CODE'))
                  }}
                  <span class="ltr:ml-1 rtl:mr-1 font-normal text-n-slate-10">
                    {{ '·' }}
                    {{
                      t(
                        i18nKey('LICENSES.GROUP_COUNT'),
                        { count: group.items.length },
                        group.items.length
                      )
                    }}
                  </span>
                </td>
              </tr>
              <tr
                v-for="license in group.items"
                :key="license.id"
                class="cursor-pointer group hover:bg-n-alpha-1"
                :class="{ 'opacity-60': !license.active }"
                @click="startEdit(license)"
              >
                <td
                  class="sticky px-3 py-2.5 border-t ltr:left-0 rtl:right-0 border-n-weak bg-n-solid-1 group-hover:bg-n-solid-2"
                >
                  <div class="flex items-center gap-2.5 min-w-[9rem]">
                    <Avatar :name="license.user_name" :size="28" rounded-full />
                    <span class="font-medium truncate text-n-slate-12">
                      {{ license.user_name }}
                    </span>
                  </div>
                </td>
                <td
                  class="px-3 py-2.5 border-t tabular-nums border-n-weak text-n-slate-12"
                >
                  {{ license.code }}
                </td>
                <td class="px-3 py-2.5 border-t border-n-weak text-n-slate-12">
                  {{ license.license_type }}
                </td>
                <td class="px-3 py-2.5 border-t border-n-weak">
                  <div class="flex flex-wrap gap-1">
                    <UpdateServerModuleChip
                      v-for="mod in modulesOfLicense(license, modules)"
                      :key="mod.id"
                      :code="mod.code"
                      :name="mod.name"
                      :inactive="!mod.active"
                    />
                  </div>
                </td>
                <td class="px-3 py-2.5 border-t border-n-weak">
                  <UpdateServerStatusSwitch
                    :active="license.active"
                    :busy="togglingId === license.id"
                    :label="
                      t(i18nKey('LICENSES.TOGGLE'), { user: license.user_name })
                    "
                    @toggle="toggleActive(license, $event)"
                  />
                </td>
                <td class="px-2 py-2.5 text-right border-t border-n-weak">
                  <Button
                    v-tooltip.top="t(i18nKey('EDIT'))"
                    :aria-label="t(i18nKey('EDIT'))"
                    icon="i-lucide-pencil"
                    ghost
                    slate
                    xs
                    @click.stop="startEdit(license)"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </InfoCard>
</template>
