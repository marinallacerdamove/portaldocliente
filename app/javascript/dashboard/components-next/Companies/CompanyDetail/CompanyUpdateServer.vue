<script setup>
// PATCH LOCAL (fork) - aba Update Server da empresa, igual à do Portal: bases
// do Albatross e licenças por usuário, com o total por módulo somado sozinho.
// Os dados moram no Portal do Cliente (repasse em
// Companies::PortalUpdateServerController); aqui não há exclusão, só inativar.
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CompanyAPI from 'dashboard/api/companies';
import Button from 'dashboard/components-next/button/Button.vue';
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
const moduleFilter = ref('');
const isRefreshing = ref(false);
const lastUpdatedAt = ref(null);
// Formulário, lote ou painel de módulos aberto em cada seção: nesse caso a
// tela não recarrega sozinha (senão apagaria o que a pessoa está digitando).
const openSections = ref({ bases: false, licenses: false });
const isEditing = computed(() =>
  Object.values(openSections.value).some(Boolean)
);

// silent = recarga em segundo plano: mantém a tela e os dados que já estão
// nela (sem esqueleto) e, se falhar, não troca a tela por erro.
const load = async ({ silent = false } = {}) => {
  if (silent) isRefreshing.value = true;
  else {
    isLoading.value = true;
    isNotLinked.value = false;
    loadFailed.value = false;
  }
  try {
    ({ data: data.value } = await CompanyAPI.getUpdateServer(props.companyId));
    lastUpdatedAt.value = new Date();
  } catch (error) {
    if (!silent) {
      if (error.response?.status === 404) isNotLinked.value = true;
      else loadFailed.value = true;
    }
  } finally {
    isLoading.value = false;
    isRefreshing.value = false;
  }
};

const reload = () => load({ silent: true });

// Volta ao foco da aba ou da janela: atualiza se nada estiver aberto/salvando.
const refreshIfIdle = () => {
  if (document.visibilityState !== 'visible') return;
  if (
    isLoading.value ||
    isRefreshing.value ||
    isSaving.value ||
    isEditing.value
  )
    return;
  reload();
};

const lastUpdatedLabel = computed(() =>
  lastUpdatedAt.value
    ? lastUpdatedAt.value.toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit',
      })
    : ''
);

// Erro do Portal (422) vem com a lista de mensagens; qualquer outro vira a
// mensagem genérica. perform devolve { ok, message } sem alerta (o lote de
// licenças junta as mensagens); save mostra o alerta e devolve true/false pro
// formulário saber se fecha.
const perform = async request => {
  isSaving.value = true;
  try {
    ({ data: data.value } = await request());
    return { ok: true, message: '' };
  } catch (error) {
    const messages = error.response?.data?.errors;
    return {
      ok: false,
      message: messages?.length
        ? messages.join(' ')
        : t('COMPANIES.DETAIL.UPDATE_SERVER.SAVE_ERROR'),
    };
  } finally {
    isSaving.value = false;
  }
};

const save = async request => {
  const result = await perform(request);
  if (!result.ok) useAlert(result.message);
  return result.ok;
};

const saveBase = (baseId, base) =>
  save(() => CompanyAPI.saveUpdateServerBase(props.companyId, baseId, base));

const licenseRequest = (licenseId, license) => () =>
  CompanyAPI.saveUpdateServerLicense(props.companyId, licenseId, license);

const saveLicense = (licenseId, license) =>
  save(licenseRequest(licenseId, license));

const saveLicenseQuiet = (licenseId, license) =>
  perform(licenseRequest(licenseId, license));

// Módulo de licença é cadastro global: a resposta do Portal é só o módulo, então
// depois de gravar a tela é recarregada (módulos, totais e licenças).
const moduleRequest = async request => {
  isSaving.value = true;
  try {
    await request();
    await reload();
    return { ok: true, message: '' };
  } catch (error) {
    const messages = error.response?.data?.errors;
    return {
      ok: false,
      message: messages?.length
        ? messages.join(' ')
        : t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.MODULES_PANEL.SAVE_ERROR'),
    };
  } finally {
    isSaving.value = false;
  }
};

const saveModule = (moduleId, attributes) =>
  moduleRequest(() =>
    CompanyAPI.saveUpdateServerModule(props.companyId, moduleId, attributes)
  );

const reorderModules = ids =>
  moduleRequest(() =>
    CompanyAPI.reorderUpdateServerModules(props.companyId, ids)
  );

onMounted(() => {
  load();
  document.addEventListener('visibilitychange', refreshIfIdle);
});
onBeforeUnmount(() =>
  document.removeEventListener('visibilitychange', refreshIfIdle)
);
watch(
  () => props.companyId,
  () => load()
);
</script>

<template>
  <div class="flex flex-col gap-4">
    <div
      v-if="isLoading"
      class="flex flex-col gap-3 p-4 border shadow-sm rounded-xl border-n-weak bg-n-solid-1 animate-pulse"
      role="status"
      :aria-label="t('COMPANIES.DETAIL.LOADING')"
    >
      <div class="w-1/4 h-4 rounded bg-n-alpha-2" />
      <div class="w-full h-8 rounded bg-n-alpha-2" />
      <div class="w-full h-8 rounded bg-n-alpha-2" />
      <div class="w-3/4 h-8 rounded bg-n-alpha-2" />
    </div>
    <InfoCard
      v-else-if="isNotLinked || loadFailed"
      :title="t('COMPANIES.DETAIL.UPDATE_SERVER.TITLE')"
      icon="i-lucide-server"
    >
      <template #actions>
        <span />
      </template>
      <p v-if="isNotLinked" class="my-0 text-sm text-n-slate-11">
        {{ t('COMPANIES.DETAIL.UPDATE_SERVER.NOT_LINKED') }}
      </p>
      <div v-else class="flex items-center gap-3">
        <p class="my-0 text-sm text-n-ruby-11">
          {{ t('COMPANIES.DETAIL.UPDATE_SERVER.LOAD_ERROR') }}
        </p>
        <Button
          :label="t('COMPANIES.DETAIL.UPDATE_SERVER.RETRY')"
          ghost
          slate
          xs
          @click="load()"
        />
      </div>
    </InfoCard>
    <template v-else>
      <div class="flex items-center justify-end gap-2">
        <span
          v-if="lastUpdatedLabel"
          class="text-xs text-n-slate-10"
          aria-live="polite"
        >
          {{
            t('COMPANIES.DETAIL.UPDATE_SERVER.UPDATED_AT', {
              time: lastUpdatedLabel,
            })
          }}
        </span>
        <Button
          :label="t('COMPANIES.DETAIL.UPDATE_SERVER.REFRESH')"
          icon="i-lucide-refresh-cw"
          ghost
          slate
          xs
          :is-loading="isRefreshing"
          :disabled="isRefreshing"
          @click="reload"
        />
      </div>
      <CompanyUpdateServerBases
        :bases="data.bases"
        :is-saving="isSaving"
        :save="saveBase"
        @busy-change="openSections.bases = $event"
      />
      <CompanyUpdateServerSummary
        :summary="data.summary"
        :selected="moduleFilter"
        @select="moduleFilter = $event"
      />
      <CompanyUpdateServerLicenses
        v-model:module-filter="moduleFilter"
        :licenses="data.licenses"
        :modules="data.modules"
        :is-saving="isSaving"
        :save="saveLicense"
        :save-each="saveLicenseQuiet"
        :save-module="saveModule"
        :reorder-modules="reorderModules"
        @busy-change="openSections.licenses = $event"
      />
    </template>
  </div>
</template>
