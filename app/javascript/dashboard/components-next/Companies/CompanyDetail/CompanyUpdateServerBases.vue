<script setup>
// Tabela de bases do Update Server (Albatross) com busca, filtro, ordenação,
// copiar banco, exportar CSV e formulário de adicionar e editar. Sem exclusão:
// a base sai de uso desligando "Ativa".
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { downloadCsvFile } from 'dashboard/helper/downloadHelper';
import { formatCnpj } from 'dashboard/helper/cnpj';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import UpdateServerEmpty from './UpdateServerEmpty.vue';
import UpdateServerSortableTh from './UpdateServerSortableTh.vue';
import UpdateServerStatusSwitch from './UpdateServerStatusSwitch.vue';
import UpdateServerToolbar from './UpdateServerToolbar.vue';
import { useUpdateServerList } from './useUpdateServerList';
import { isHttpLink, linkDomain, toCsv } from './updateServerHelpers';

const props = defineProps({
  bases: { type: Array, default: () => [] },
  isSaving: { type: Boolean, default: false },
  save: { type: Function, required: true },
});

const emit = defineEmits(['busyChange']);

const { t } = useI18n();

const FIELDS = [
  { key: 'albatross_id', type: 'number', required: true, section: 'identity' },
  { key: 'display_code', type: 'number', section: 'identity' },
  { key: 'razao_social', section: 'identity' },
  { key: 'display_name', section: 'identity' },
  { key: 'database_name', section: 'access' },
  { key: 'link', section: 'access' },
  { key: 'documento', section: 'access' },
];
const SECTIONS = ['identity', 'access'];
const FIELDS_WITH_HELP = [
  'albatross_id',
  'display_code',
  'database_name',
  'link',
  'documento',
];
const CSV_FILE_NAME = 'update-server-bases.csv';

const list = useUpdateServerList(() => props.bases, {
  searchKeys: [
    'albatross_id',
    'display_code',
    'razao_social',
    'display_name',
    'database_name',
    'documento',
  ],
  sortKey: 'albatross_id',
});

const i18nKey = suffix => `COMPANIES.DETAIL.UPDATE_SERVER.${suffix}`;

const emptyDraft = () => ({
  albatross_id: '',
  display_code: '',
  razao_social: '',
  display_name: '',
  database_name: '',
  link: '',
  documento: '',
  active: true,
});

const editingId = ref(null); // 'new' ou o id da base
const draft = ref(emptyDraft());
const togglingId = ref(null);
const copiedId = ref(null);

// O container só recarrega sozinho quando nenhum formulário está aberto.
watch(
  () => editingId.value !== null,
  busy => emit('busyChange', busy)
);

const startNew = () => {
  draft.value = emptyDraft();
  editingId.value = 'new';
};

const startEdit = base => {
  draft.value = { ...emptyDraft(), ...base };
  editingId.value = base.id;
};

const cancel = () => {
  editingId.value = null;
};

const submit = async () => {
  const attributes = Object.fromEntries(
    [...FIELDS.map(field => field.key), 'active'].map(key => [
      key,
      draft.value[key],
    ])
  );
  const baseId = editingId.value === 'new' ? null : editingId.value;
  if (await props.save(baseId, attributes)) editingId.value = null;
};

// Ativar/desativar na linha: só o campo "active" vai (o Portal aceita parcial).
const toggleActive = async (base, active) => {
  togglingId.value = base.id;
  await props.save(base.id, { active });
  togglingId.value = null;
};

const copyDatabase = async base => {
  try {
    await copyTextToClipboard(base.database_name);
    copiedId.value = base.id;
    setTimeout(() => {
      if (copiedId.value === base.id) copiedId.value = null;
    }, 1500);
  } catch {
    useAlert(t(i18nKey('COPY_ERROR')));
  }
};

const exportCsv = () => {
  const columns = [
    ...FIELDS.map(field => ({
      header: t(i18nKey(`BASES.FIELDS.${field.key}`)),
      value: base => base[field.key],
    })),
    {
      header: t(i18nKey('ACTIVE')),
      value: base => (base.active ? t(i18nKey('YES')) : t(i18nKey('NO'))),
    },
  ];
  downloadCsvFile(CSV_FILE_NAME, toCsv(list.visible.value, columns));
};
</script>

<template>
  <InfoCard :title="t(i18nKey('BASES.TITLE'))" icon="i-lucide-database">
    <template #actions>
      <Button
        v-if="editingId === null && bases.length"
        :label="t(i18nKey('BASES.ADD'))"
        icon="i-lucide-plus"
        ghost
        slate
        xs
        @click="startNew"
      />
      <span v-else />
    </template>

    <p class="mt-0 mb-4 text-xs text-n-slate-11">
      {{ t(i18nKey('BASES.DESCRIPTION')) }}
    </p>

    <div
      v-if="editingId !== null"
      class="flex flex-col gap-4 p-4 mb-4 border rounded-lg border-n-weak bg-n-alpha-1"
    >
      <p class="my-0 text-sm font-medium text-n-slate-12">
        {{
          t(i18nKey(editingId === 'new' ? 'BASES.FORM_NEW' : 'BASES.FORM_EDIT'))
        }}
      </p>
      <fieldset
        v-for="section in SECTIONS"
        :key="section"
        class="flex flex-col gap-3 p-0 m-0 border-0"
      >
        <legend
          class="p-0 mb-2 text-xs font-semibold uppercase text-n-slate-10"
        >
          {{ t(i18nKey(`BASES.SECTIONS.${section.toUpperCase()}`)) }}
        </legend>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <Input
            v-for="field in FIELDS.filter(item => item.section === section)"
            :key="field.key"
            v-model="draft[field.key]"
            :type="field.type || 'text'"
            :label="t(i18nKey(`BASES.FIELDS.${field.key}`))"
            :placeholder="t(i18nKey(`BASES.PLACEHOLDERS.${field.key}`))"
            :message="
              FIELDS_WITH_HELP.includes(field.key)
                ? t(i18nKey(`BASES.HELP.${field.key}`))
                : ''
            "
            :disabled="isSaving"
            custom-input-class="h-8 !pt-1 !pb-1"
          />
        </div>
      </fieldset>
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <Checkbox v-model="draft.active" :disabled="isSaving" />
        {{ t(i18nKey('ACTIVE')) }}
      </label>
      <div class="flex items-center justify-end gap-2">
        <Button :label="t(i18nKey('CANCEL'))" ghost slate xs @click="cancel" />
        <Button
          :label="isSaving ? t(i18nKey('SAVING')) : t(i18nKey('SAVE'))"
          :disabled="isSaving || !draft.albatross_id"
          xs
          @click="submit"
        />
      </div>
    </div>

    <UpdateServerEmpty
      v-if="!bases.length"
      icon="i-lucide-database"
      :title="t(i18nKey('BASES.EMPTY_TITLE'))"
      :description="t(i18nKey('BASES.EMPTY'))"
    >
      <Button
        v-if="editingId === null"
        :label="t(i18nKey('BASES.EMPTY_CTA'))"
        icon="i-lucide-plus"
        xs
        @click="startNew"
      />
    </UpdateServerEmpty>

    <template v-else>
      <UpdateServerToolbar
        v-model:search="list.search.value"
        v-model:status="list.status.value"
        :search-placeholder="t(i18nKey('BASES.SEARCH'))"
        :counts="list.counts.value"
        :shown="list.visible.value.length"
        :total="bases.length"
      >
        <template #actions>
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
          @click="list.clearFilters"
        />
      </UpdateServerEmpty>
      <div
        v-else
        class="overflow-auto border rounded-lg max-h-[28rem] border-n-weak"
      >
        <table
          class="w-full text-sm text-left border-separate border-spacing-0"
        >
          <thead>
            <tr>
              <UpdateServerSortableTh
                v-for="(field, index) in FIELDS"
                :key="field.key"
                :label="t(i18nKey(`BASES.FIELDS.${field.key}`))"
                :sort-key="field.key"
                :active-key="list.sortBy.value"
                :direction="list.sortDirection.value"
                :sticky="index === 0"
                :numeric="field.type === 'number'"
                @sort="list.toggleSort"
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
          <tbody>
            <tr
              v-for="base in list.visible.value"
              :key="base.id"
              class="cursor-pointer group hover:bg-n-alpha-1"
              :class="{ 'opacity-60': !base.active }"
              @click="startEdit(base)"
            >
              <td
                class="sticky px-3 py-3 font-medium tabular-nums border-t ltr:left-0 ltr:text-right rtl:right-0 rtl:text-left border-n-weak bg-n-solid-1 text-n-slate-12 group-hover:bg-n-solid-2"
              >
                {{ base.albatross_id }}
              </td>
              <td
                class="px-3 py-3 border-t tabular-nums ltr:text-right rtl:text-left border-n-weak text-n-slate-12"
              >
                {{ base.display_code ?? '' }}
              </td>
              <td class="px-3 py-3 border-t border-n-weak text-n-slate-12">
                {{ base.razao_social }}
              </td>
              <td class="px-3 py-3 border-t border-n-weak text-n-slate-12">
                {{ base.display_name }}
              </td>
              <td class="px-3 py-3 border-t border-n-weak">
                <div v-if="base.database_name" class="flex items-center gap-1">
                  <span class="font-mono text-xs text-n-slate-12">
                    {{ base.database_name }}
                  </span>
                  <Button
                    v-tooltip.top="
                      copiedId === base.id
                        ? t(i18nKey('COPIED'))
                        : t(i18nKey('COPY'))
                    "
                    :icon="
                      copiedId === base.id ? 'i-lucide-check' : 'i-lucide-copy'
                    "
                    :aria-label="t(i18nKey('COPY'))"
                    ghost
                    slate
                    xs
                    @click.stop="copyDatabase(base)"
                  />
                </div>
              </td>
              <td class="px-3 py-3 border-t border-n-weak">
                <a
                  v-if="isHttpLink(base.link)"
                  v-tooltip.top="linkDomain(base.link)"
                  :href="base.link"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-1 text-xs text-n-blue-11 hover:underline"
                  @click.stop
                >
                  {{ t(i18nKey('OPEN')) }}
                  <span class="i-lucide-external-link size-3" />
                </a>
              </td>
              <td
                class="px-3 py-3 font-mono text-xs border-t tabular-nums border-n-weak text-n-slate-12"
              >
                {{ base.documento ? formatCnpj(base.documento) : '' }}
              </td>
              <td class="px-3 py-3 border-t border-n-weak">
                <UpdateServerStatusSwitch
                  :active="base.active"
                  :busy="togglingId === base.id"
                  :label="t(i18nKey('TOGGLE_BASE'), { id: base.albatross_id })"
                  @toggle="toggleActive(base, $event)"
                />
              </td>
              <td class="px-2 py-3 text-right border-t border-n-weak">
                <Button
                  v-tooltip.top="t(i18nKey('EDIT'))"
                  :aria-label="t(i18nKey('EDIT'))"
                  icon="i-lucide-pencil"
                  ghost
                  slate
                  xs
                  @click.stop="startEdit(base)"
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </InfoCard>
</template>
