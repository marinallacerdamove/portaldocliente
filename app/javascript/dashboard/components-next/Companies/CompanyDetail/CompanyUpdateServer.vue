<script setup>
// PATCH LOCAL (fork) - aba Update Server da empresa, igual à do Portal: bases
// do Albatross e licenças por usuário, com o total por módulo somado sozinho.
// Os dados moram no Portal do Cliente (repasse em
// Companies::PortalUpdateServerController); aqui não há exclusão, só inativar.
import { onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CompanyAPI from 'dashboard/api/companies';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import CompanyUpdateServerBases from './CompanyUpdateServerBases.vue';
import CompanyUpdateServerLicenses from './CompanyUpdateServerLicenses.vue';
import CompanyUpdateServerSummary from './CompanyUpdateServerSummary.vue';

const props = defineProps({
  companyId: { type: [Number, String], required: true },
});

const { t } = useI18n();

const data = ref({ bases: [], licenses: [], modules: [], summary: null });
const isLoading = ref(false);
const isNotLinked = ref(false);
const loadFailed = ref(false);
const isSaving = ref(false);

const load = async () => {
  isLoading.value = true;
  isNotLinked.value = false;
  loadFailed.value = false;
  try {
    ({ data: data.value } = await CompanyAPI.getUpdateServer(props.companyId));
  } catch (error) {
    if (error.response?.status === 404) isNotLinked.value = true;
    else loadFailed.value = true;
  } finally {
    isLoading.value = false;
  }
};

// Erro do Portal (422) vem com a lista de mensagens; qualquer outro vira a
// mensagem genérica. Devolve true quando gravou, pro formulário fechar.
const save = async request => {
  isSaving.value = true;
  try {
    ({ data: data.value } = await request());
    return true;
  } catch (error) {
    const messages = error.response?.data?.errors;
    useAlert(
      messages?.length
        ? messages.join(' ')
        : t('COMPANIES.DETAIL.UPDATE_SERVER.SAVE_ERROR')
    );
    return false;
  } finally {
    isSaving.value = false;
  }
};

const saveBase = (baseId, base) =>
  save(() => CompanyAPI.saveUpdateServerBase(props.companyId, baseId, base));

const saveLicense = (licenseId, license) =>
  save(() =>
    CompanyAPI.saveUpdateServerLicense(props.companyId, licenseId, license)
  );

onMounted(load);
watch(() => props.companyId, load);
</script>

<template>
  <div class="flex flex-col gap-4">
    <InfoCard
      v-if="isLoading || isNotLinked || loadFailed"
      :title="t('COMPANIES.DETAIL.UPDATE_SERVER.TITLE')"
      icon="i-lucide-server"
    >
      <template #actions>
        <span />
      </template>
      <p v-if="isLoading" class="my-0 text-sm text-n-slate-11">
        {{ t('COMPANIES.DETAIL.LOADING') }}
      </p>
      <p v-else-if="isNotLinked" class="my-0 text-sm text-n-slate-11">
        {{ t('COMPANIES.DETAIL.UPDATE_SERVER.NOT_LINKED') }}
      </p>
      <p v-else class="my-0 text-sm text-n-ruby-11">
        {{ t('COMPANIES.DETAIL.UPDATE_SERVER.LOAD_ERROR') }}
      </p>
    </InfoCard>
    <template v-else>
      <CompanyUpdateServerBases
        :bases="data.bases"
        :is-saving="isSaving"
        :save="saveBase"
      />
      <CompanyUpdateServerLicenses
        :licenses="data.licenses"
        :modules="data.modules"
        :is-saving="isSaving"
        :save="saveLicense"
      />
      <CompanyUpdateServerSummary :summary="data.summary" />
    </template>
  </div>
</template>
