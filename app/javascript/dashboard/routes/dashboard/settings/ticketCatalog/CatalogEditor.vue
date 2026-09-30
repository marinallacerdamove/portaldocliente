<script setup>
// PATCH LOCAL (fork) - ficha de criar/editar um cadastro de atendimento, no
// padrão da ficha de Macro (cards InfoCard). O card "Principal" (nome, tipo de
// ticket, ativo) é comum aos quatro; o resto vem do componente do tipo. Só
// administrador salva; agente vê em modo leitura. Sem excluir: inativar.
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useTicketCatalog } from 'dashboard/composables/useTicketCatalog';
import Button from 'dashboard/components-next/button/Button.vue';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import ServiceFields from './ServiceFields.vue';
import CategoryFields from './CategoryFields.vue';
import StatusFields from './StatusFields.vue';
import JustificationFields from './JustificationFields.vue';
import CustomFieldFields from './CustomFieldFields.vue';
import FieldRuleFields from './FieldRuleFields.vue';
import {
  catalogPayload,
  editableCatalogRecord,
  newCatalogRecord,
} from './catalogHelper';
import { CATALOG_KINDS, TICKET_SCOPES, catalogRouteName } from './constants';

const props = defineProps({
  kind: {
    type: String,
    required: true,
    validator: value => Object.keys(CATALOG_KINDS).includes(value),
  },
});

const KIND_FIELDS = {
  services: ServiceFields,
  categories: CategoryFields,
  statuses: StatusFields,
  justifications: JustificationFields,
  customFields: CustomFieldFields,
  fieldRules: FieldRuleFields,
};

// Listas de apoio de cada ficha (pai/categorias do serviço, status da
// justificativa, o que as condições e campos da regra podem escolher).
const RELATED_LISTS = {
  services: ['categories'],
  categories: [],
  statuses: [],
  justifications: ['statuses'],
  customFields: [],
  fieldRules: ['customFields', 'services', 'categories', 'statuses'],
};

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();
const { isAdmin } = useAdmin();
const { state, fetchList, saveRecord } = useTicketCatalog();

const { i18nKey, hasScope = true } = CATALOG_KINDS[props.kind];
const record = ref(null);
const isLoading = ref(false);
const isSaving = ref(false);
const nameError = ref('');

// A instância (em cache por caminho, keep-alive) fica presa à rota de entrada.
const ownPath = route.fullPath;
const recordId = Number(route.params.recordId) || null;
const isEdit = Boolean(recordId);
const readOnly = computed(() => !isAdmin.value);

const scopeOptions = computed(() =>
  TICKET_SCOPES.map(scope => ({
    value: scope,
    label: t(`TICKET_CATALOG.TICKET_SCOPES.${scope}`),
  }))
);

const goToList = () =>
  router.push({ name: catalogRouteName(props.kind, 'list') });

const load = async () => {
  isLoading.value = true;
  record.value = null;
  nameError.value = '';
  try {
    await Promise.all([
      fetchList(props.kind, { force: true }),
      ...RELATED_LISTS[props.kind].map(kind => fetchList(kind)),
      props.kind === 'services' && store.dispatch('macros/get'),
      props.kind === 'fieldRules' && store.dispatch('teams/get'),
      props.kind === 'fieldRules' && store.dispatch('agents/get'),
    ]);
    if (!isEdit) {
      record.value = newCatalogRecord(props.kind);
      return;
    }
    const existing = state[props.kind].find(item => item.id === recordId);
    if (!existing) {
      useAlert(t('TICKET_CATALOG.FORM.LOAD_ERROR'));
      goToList();
      return;
    }
    record.value = editableCatalogRecord(props.kind, existing);
  } catch (error) {
    useAlert(
      error?.response?.data?.message || t('TICKET_CATALOG.FORM.LOAD_ERROR')
    );
  } finally {
    isLoading.value = false;
  }
};

// Recarrega a cada volta pra esta ficha: um "novo" em cache não pode reabrir
// com o que foi digitado antes.
watch(
  () => route.fullPath,
  path => {
    if (path === ownPath) load();
  },
  { immediate: true }
);

const submit = async () => {
  if (readOnly.value) return;
  nameError.value = record.value.name.trim()
    ? ''
    : t('TICKET_CATALOG.FORM.NAME_REQUIRED');
  if (nameError.value) return;

  isSaving.value = true;
  try {
    await saveRecord(props.kind, catalogPayload(props.kind, record.value));
    useAlert(
      isEdit
        ? t('TICKET_CATALOG.FORM.UPDATE_SUCCESS')
        : t('TICKET_CATALOG.FORM.CREATE_SUCCESS')
    );
    goToList();
  } catch (error) {
    useAlert(
      error?.response?.data?.message || t('TICKET_CATALOG.FORM.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col w-full h-full !px-6 overflow-y-auto">
    <woot-loading-state
      v-if="isLoading"
      :message="t('TICKET_CATALOG.LIST.LOADING')"
    />
    <div v-else-if="record" class="flex flex-col w-full max-w-4xl gap-4 py-6">
      <header class="flex flex-wrap items-start justify-between gap-3">
        <div class="flex flex-col gap-1">
          <h1 class="my-0 text-xl font-semibold text-n-slate-12">
            {{
              isEdit
                ? t(`TICKET_CATALOG.${i18nKey}.EDIT_TITLE`)
                : t(`TICKET_CATALOG.${i18nKey}.NEW_TITLE`)
            }}
          </h1>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ t(`TICKET_CATALOG.${i18nKey}.SUBTITLE`) }}
          </p>
        </div>
        <div class="flex items-center gap-2">
          <Button
            :label="t('TICKET_CATALOG.FORM.CANCEL')"
            ghost
            slate
            sm
            @click="goToList"
          />
          <Button
            :label="t('TICKET_CATALOG.FORM.SUBMIT')"
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
        {{ t('TICKET_CATALOG.FORM.READ_ONLY') }}
      </p>

      <div
        :inert="readOnly"
        class="flex flex-col gap-4"
        :class="{ 'opacity-75': readOnly }"
      >
        <InfoCard
          :title="t('TICKET_CATALOG.FORM.MAIN_TITLE')"
          icon="i-lucide-settings-2"
        >
          <template #actions>
            <span />
          </template>
          <div class="flex flex-col gap-4">
            <div class="grid gap-4" :class="{ 'sm:grid-cols-2': hasScope }">
              <Input
                id="catalog-name"
                v-model="record.name"
                :label="t('TICKET_CATALOG.FORM.NAME_LABEL')"
                :placeholder="t('TICKET_CATALOG.FORM.NAME_PLACEHOLDER')"
                :message="nameError"
                :message-type="nameError ? 'error' : 'info'"
              />
              <div v-if="hasScope" class="flex flex-col gap-1">
                <SelectInput
                  id="catalog-ticket-scope"
                  v-model="record.ticket_scope"
                  :label="t('TICKET_CATALOG.FORM.TICKET_SCOPE_LABEL')"
                  :options="scopeOptions"
                />
                <p class="mb-0 text-xs text-n-slate-10">
                  {{ t('TICKET_CATALOG.FORM.TICKET_SCOPE_HINT') }}
                </p>
              </div>
            </div>
            <SettingsToggleSection
              v-model="record.active"
              :header="t('TICKET_CATALOG.FORM.ACTIVE_LABEL')"
              :description="t('TICKET_CATALOG.FORM.ACTIVE_HINT')"
            />
          </div>
        </InfoCard>

        <component :is="KIND_FIELDS[kind]" v-model:record="record" />
      </div>
    </div>
  </div>
</template>
