<script setup>
// PATCH LOCAL (fork) - campos próprios do serviço (Movidesk: Serviços): lugar
// na árvore, visibilidade pro cliente, categorias permitidas, padrões que a
// conversa recebe e a macro disparada ao escolher o serviço.
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useTicketCatalog } from 'dashboard/composables/useTicketCatalog';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import ToggleChips from './ToggleChips.vue';
import { buildServiceTree, serviceSubtreeIds } from './catalogHelper';
import { PRIORITIES } from './constants';

const record = defineModel('record', { type: Object, required: true });

const { t } = useI18n();
const { state } = useTicketCatalog();
const macros = useMapGetter('macros/getMacros');

const withInactiveMark = (item, name = item.name) =>
  item.active ? name : t('TICKET_CATALOG.FORM.INACTIVE_OPTION', { name });

// <select> não trabalha com null: '' representa "nenhum".
const nullableSelect = key =>
  computed({
    get: () => record.value[key] ?? '',
    set: value => {
      record.value[key] = value === '' ? null : value;
    },
  });

const parentId = nullableSelect('parent_id');
const defaultCategoryId = nullableSelect('default_category_id');
const defaultPriority = nullableSelect('default_priority');
const macroId = nullableSelect('macro_id');

// Pai: qualquer serviço fora da própria subárvore (evita ciclo).
const parentOptions = computed(() => {
  const blocked = serviceSubtreeIds(state.services, record.value.id);
  return [
    { value: '', label: t('TICKET_CATALOG.SERVICES.FORM.PARENT_NONE') },
    ...buildServiceTree(state.services)
      .filter(service => !blocked.has(service.id))
      .map(service => ({
        value: service.id,
        label: withInactiveMark(service, service.full_name),
      })),
  ];
});

// Categoria inativa só aparece se já estiver escolhida (pra poder tirar).
const categoryOptions = computed(() =>
  state.categories
    .filter(
      category =>
        category.active || record.value.category_ids.includes(category.id)
    )
    .map(category => ({ id: category.id, name: withInactiveMark(category) }))
);

const allowedCategories = computed(() =>
  state.categories.filter(
    category =>
      (category.active || category.id === record.value.default_category_id) &&
      (record.value.all_categories ||
        record.value.category_ids.includes(category.id))
  )
);

// Categoria padrão tem que estar entre as permitidas.
watch(allowedCategories, categories => {
  if (!categories.some(({ id }) => id === record.value.default_category_id)) {
    record.value.default_category_id = null;
  }
});

const defaultCategoryOptions = computed(() => [
  { value: '', label: t('TICKET_CATALOG.SERVICES.FORM.DEFAULT_CATEGORY_NONE') },
  ...allowedCategories.value.map(category => ({
    value: category.id,
    label: withInactiveMark(category),
  })),
]);

const priorityOptions = computed(() => [
  { value: '', label: t('TICKET_CATALOG.PRIORITIES.NONE') },
  ...PRIORITIES.map(priority => ({
    value: priority,
    label: t(`TICKET_CATALOG.PRIORITIES.${priority}`),
  })),
]);

// Macro pessoal não roda pra quem escolhe o serviço (o backend recusa).
const macroOptions = computed(() => [
  { value: '', label: t('TICKET_CATALOG.SERVICES.FORM.MACRO_NONE') },
  ...macros.value
    .filter(macro => macro.visibility !== 'personal')
    .map(macro => ({ value: macro.id, label: macro.name })),
]);
</script>

<template>
  <InfoCard
    :title="t('TICKET_CATALOG.SERVICES.FORM.DETAILS_TITLE')"
    icon="i-lucide-folder-tree"
  >
    <template #actions>
      <span />
    </template>
    <div class="flex flex-col gap-4">
      <SelectInput
        id="service-parent"
        v-model="parentId"
        :label="t('TICKET_CATALOG.SERVICES.FORM.PARENT_LABEL')"
        :options="parentOptions"
        class="sm:max-w-md"
      />
      <TextArea
        id="service-description"
        v-model="record.description"
        :label="t('TICKET_CATALOG.SERVICES.FORM.DESCRIPTION_LABEL')"
        :placeholder="t('TICKET_CATALOG.SERVICES.FORM.DESCRIPTION_PLACEHOLDER')"
        :max-length="1000"
        auto-height
      />
      <div class="grid gap-3 sm:grid-cols-2">
        <SettingsToggleSection
          v-model="record.visible_to_clients"
          :header="t('TICKET_CATALOG.SERVICES.FORM.VISIBLE_LABEL')"
          :description="
            record.visible_to_clients
              ? t('TICKET_CATALOG.SERVICES.FORM.VISIBLE_HINT')
              : t('TICKET_CATALOG.SERVICES.FORM.INTERNAL_HINT')
          "
        />
        <SettingsToggleSection
          v-model="record.allow_finish"
          :header="t('TICKET_CATALOG.SERVICES.FORM.ALLOW_FINISH_LABEL')"
          :description="t('TICKET_CATALOG.SERVICES.FORM.ALLOW_FINISH_HINT')"
        />
      </div>
    </div>
  </InfoCard>

  <InfoCard
    :title="t('TICKET_CATALOG.SERVICES.FORM.RULES_TITLE')"
    icon="i-lucide-list-checks"
  >
    <template #actions>
      <span />
    </template>
    <div class="flex flex-col gap-4">
      <SettingsToggleSection
        v-model="record.all_categories"
        :header="t('TICKET_CATALOG.SERVICES.FORM.ALL_CATEGORIES_LABEL')"
        :description="t('TICKET_CATALOG.SERVICES.FORM.ALL_CATEGORIES_HINT')"
      />
      <div v-if="!record.all_categories" class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('TICKET_CATALOG.SERVICES.FORM.CATEGORIES_LABEL') }}
        </span>
        <ToggleChips
          v-model="record.category_ids"
          :options="categoryOptions"
          :empty-message="t('TICKET_CATALOG.SERVICES.FORM.NO_CATEGORIES')"
        />
      </div>
      <div class="grid gap-4 sm:grid-cols-2">
        <SelectInput
          id="service-default-category"
          v-model="defaultCategoryId"
          :label="t('TICKET_CATALOG.SERVICES.FORM.DEFAULT_CATEGORY_LABEL')"
          :options="defaultCategoryOptions"
        />
        <SelectInput
          id="service-default-priority"
          v-model="defaultPriority"
          :label="t('TICKET_CATALOG.SERVICES.FORM.DEFAULT_PRIORITY_LABEL')"
          :options="priorityOptions"
        />
      </div>
      <div class="flex flex-col gap-1 sm:max-w-md">
        <SelectInput
          id="service-macro"
          v-model="macroId"
          :label="t('TICKET_CATALOG.SERVICES.FORM.MACRO_LABEL')"
          :options="macroOptions"
        />
        <p class="mb-0 text-xs text-n-slate-10">
          {{ t('TICKET_CATALOG.SERVICES.FORM.MACRO_HINT') }}
        </p>
      </div>
    </div>
  </InfoCard>
</template>
