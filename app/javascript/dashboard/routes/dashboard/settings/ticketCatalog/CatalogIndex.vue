<script setup>
// PATCH LOCAL (fork) - lista de um cadastro de atendimento (Serviços,
// Categorias, Status ou Justificativas), no padrão da lista de Macros. Filtro
// Ativos/Inativos/Todos e busca por nome; sem excluir, só inativar na ficha.
// Agente vê a lista e abre a ficha em modo leitura.
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { picoSearch } from '@chatwoot/pico-search';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useTicketCatalog } from 'dashboard/composables/useTicketCatalog';
import Button from 'dashboard/components-next/button/Button.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import { buildServiceTree } from './catalogHelper';
import { ACTIVE_FILTERS, CATALOG_KINDS, catalogRouteName } from './constants';

const props = defineProps({
  kind: {
    type: String,
    required: true,
    validator: value => Object.keys(CATALOG_KINDS).includes(value),
  },
});

// Recuo por nível da árvore de serviços (classes literais pro Tailwind).
const INDENT_CLASSES = ['', 'ps-5', 'ps-10', 'ps-16', 'ps-20'];

const { t } = useI18n();
const { isAdmin } = useAdmin();
const { state, fetchList } = useTicketCatalog();

const i18nKey = CATALOG_KINDS[props.kind].i18nKey;
const isLoading = ref(false);
const searchQuery = ref('');
const activeFilter = ref('active');

const records = computed(() =>
  props.kind === 'services'
    ? buildServiceTree(state.services)
    : state[props.kind]
);

const filterTabs = computed(() =>
  ACTIVE_FILTERS.map(filter => ({
    key: filter,
    label: t(`TICKET_CATALOG.LIST.FILTERS.${filter}`),
    count: records.value.filter(
      record => filter === 'all' || record.active === (filter === 'active')
    ).length,
  }))
);

const filteredRecords = computed(() => {
  const byActive = records.value.filter(
    record =>
      activeFilter.value === 'all' ||
      record.active === (activeFilter.value === 'active')
  );
  const query = searchQuery.value.trim();
  if (!query) return byActive;
  // Na busca a árvore se desfaz: o serviço aparece pelo caminho completo.
  return picoSearch(byActive, query, ['name', 'full_name']).map(record => ({
    ...record,
    depth: 0,
  }));
});

const statusNames = computed(() =>
  Object.fromEntries(state.statuses.map(status => [status.id, status.name]))
);

const fieldNames = computed(() =>
  Object.fromEntries(state.customFields.map(field => [field.id, field.name]))
);

const scopeLabel = record =>
  t(`TICKET_CATALOG.TICKET_SCOPES.${record.ticket_scope}`);

// Colunas entre "Nome" e "Situação", por tipo de cadastro.
const EXTRA_COLUMNS = {
  services: [
    {
      header: 'TICKET_CATALOG.LIST.TABLE_HEADER.TICKET_SCOPE',
      value: scopeLabel,
    },
  ],
  categories: [
    {
      header: 'TICKET_CATALOG.LIST.TABLE_HEADER.TICKET_SCOPE',
      value: scopeLabel,
    },
    {
      header: 'TICKET_CATALOG.CATEGORIES.TABLE_HEADER.PRIORITIES',
      value: record =>
        record.allowed_priorities.length
          ? record.allowed_priorities
              .map(priority => t(`TICKET_CATALOG.PRIORITIES.${priority}`))
              .join(', ')
          : t('TICKET_CATALOG.CATEGORIES.ALL_PRIORITIES'),
    },
  ],
  statuses: [
    {
      header: 'TICKET_CATALOG.STATUSES.TABLE_HEADER.BASE',
      value: record => t(`TICKET_CATALOG.STATUS_BASES.${record.base}`),
    },
    {
      header: 'TICKET_CATALOG.LIST.TABLE_HEADER.TICKET_SCOPE',
      value: scopeLabel,
    },
    {
      header: 'TICKET_CATALOG.STATUSES.TABLE_HEADER.REQUIRES_JUSTIFICATION',
      value: record =>
        record.requires_justification
          ? t('TICKET_CATALOG.LIST.YES')
          : t('TICKET_CATALOG.LIST.EMPTY_VALUE'),
    },
  ],
  justifications: [
    {
      header: 'TICKET_CATALOG.LIST.TABLE_HEADER.TICKET_SCOPE',
      value: scopeLabel,
    },
    {
      header: 'TICKET_CATALOG.JUSTIFICATIONS.TABLE_HEADER.STATUSES',
      value: record =>
        record.status_ids
          .map(id => statusNames.value[id])
          .filter(Boolean)
          .join(', ') || t('TICKET_CATALOG.LIST.EMPTY_VALUE'),
    },
  ],
  customFields: [
    {
      header: 'TICKET_CATALOG.CUSTOM_FIELDS.TABLE_HEADER.TYPE',
      value: record =>
        t(`TICKET_CATALOG.CUSTOM_FIELDS.TYPES.${record.field_type}`),
    },
  ],
  fieldRules: [
    {
      header: 'TICKET_CATALOG.FIELD_RULES.TABLE_HEADER.FIELDS',
      value: record =>
        record.fields
          .map(item => fieldNames.value[item.field_id])
          .filter(Boolean)
          .join(', ') || t('TICKET_CATALOG.LIST.EMPTY_VALUE'),
    },
  ],
};

const extraColumns = EXTRA_COLUMNS[props.kind];

const tableHeaders = computed(() => [
  t('TICKET_CATALOG.LIST.TABLE_HEADER.NAME'),
  ...extraColumns.map(column => t(column.header)),
  t('TICKET_CATALOG.LIST.TABLE_HEADER.ACTIVE'),
  t('TICKET_CATALOG.LIST.TABLE_HEADER.ACTIONS'),
]);

const indentClass = record =>
  INDENT_CLASSES[Math.min(record.depth || 0, INDENT_CLASSES.length - 1)];

const onFilterChanged = tab => {
  activeFilter.value = tab.key;
};

onMounted(async () => {
  isLoading.value = true;
  try {
    await Promise.all([
      fetchList(props.kind, { force: true }),
      // Justificativa mostra o nome dos status em que pode ser usada; regra,
      // o nome dos campos que exibe.
      props.kind === 'justifications' && fetchList('statuses'),
      props.kind === 'fieldRules' && fetchList('customFields'),
    ]);
  } catch (error) {
    useAlert(
      error?.response?.data?.message || t('TICKET_CATALOG.LIST.LOAD_ERROR')
    );
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <SettingsLayout
    :no-records-message="$t(`TICKET_CATALOG.${i18nKey}.EMPTY`)"
    :no-records-found="!records.length"
    :is-loading="isLoading && !records.length"
    :loading-message="$t('TICKET_CATALOG.LIST.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t(`TICKET_CATALOG.${i18nKey}.HEADER`)"
        :description="$t(`TICKET_CATALOG.${i18nKey}.DESCRIPTION`)"
        :search-placeholder="$t('TICKET_CATALOG.LIST.SEARCH_PLACEHOLDER')"
      >
        <template v-if="records.length" #tabs>
          <TabBar
            :tabs="filterTabs"
            :initial-active-tab="ACTIVE_FILTERS.indexOf(activeFilter)"
            @tab-changed="onFilterChanged"
          />
        </template>
        <template v-if="records.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('TICKET_CATALOG.LIST.COUNT', { n: records.length }) }}
          </span>
        </template>
        <template v-if="isAdmin" #actions>
          <router-link :to="{ name: catalogRouteName(kind, 'new') }">
            <Button :label="$t(`TICKET_CATALOG.${i18nKey}.NEW`)" size="sm" />
          </router-link>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="$t('TICKET_CATALOG.LIST.NO_RESULTS')"
      >
        <template #row="{ items }">
          <BaseTableRow v-for="record in items" :key="record.id" :item="record">
            <BaseTableCell class="max-w-0 min-w-0 w-2/5">
              <div
                class="flex items-center min-w-0 gap-2"
                :class="indentClass(record)"
              >
                <span
                  v-if="record.depth"
                  class="i-lucide-corner-down-right size-3.5 shrink-0 text-n-slate-10"
                />
                <span class="block truncate text-body-main text-n-slate-12">
                  {{ (searchQuery.trim() && record.full_name) || record.name }}
                </span>
                <span
                  v-if="record.visible_to_clients === false"
                  class="px-1.5 py-0.5 text-xs rounded-md shrink-0 bg-n-amber-3 text-n-amber-11"
                >
                  {{ $t('TICKET_CATALOG.SERVICES.INTERNAL_BADGE') }}
                </span>
              </div>
            </BaseTableCell>
            <BaseTableCell
              v-for="column in extraColumns"
              :key="column.header"
              class="max-w-0"
            >
              <span class="block truncate text-body-main text-n-slate-11">
                {{ column.value(record) }}
              </span>
            </BaseTableCell>
            <BaseTableCell class="w-28">
              <span
                class="px-2 py-0.5 text-xs rounded-md"
                :class="
                  record.active
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : 'bg-n-slate-3 text-n-slate-11'
                "
              >
                {{
                  record.active
                    ? $t('TICKET_CATALOG.LIST.ACTIVE')
                    : $t('TICKET_CATALOG.LIST.INACTIVE')
                }}
              </span>
            </BaseTableCell>
            <BaseTableCell align="end" class="w-20">
              <router-link
                :to="{
                  name: catalogRouteName(kind, 'edit'),
                  params: { recordId: record.id },
                }"
              >
                <Button
                  v-tooltip.top="
                    isAdmin
                      ? $t('TICKET_CATALOG.LIST.EDIT_TOOLTIP')
                      : $t('TICKET_CATALOG.LIST.VIEW_TOOLTIP')
                  "
                  :icon="isAdmin ? 'i-woot-edit-pen' : 'i-lucide-eye'"
                  slate
                  sm
                />
              </router-link>
            </BaseTableCell>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>
  </SettingsLayout>
</template>
