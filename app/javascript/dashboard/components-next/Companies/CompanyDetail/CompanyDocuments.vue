<script setup>
// PATCH LOCAL (fork) - aba Documentos da empresa, igual à do Portal: arquivos
// por categoria com observação. Os arquivos moram no Portal do Cliente
// (repasse em Companies::PortalDocumentsController).
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CompanyAPI from 'dashboard/api/companies';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { FILE_CATEGORIAS } from 'dashboard/constants/portalCompanyFields';

const props = defineProps({
  companyId: { type: [Number, String], required: true },
});

const { t } = useI18n();

const files = ref([]);
const isLoading = ref(false);
const isNotLinked = ref(false);
const loadFailed = ref(false);
const uploadingCategoria = ref('');
const editingFileId = ref(null);
const observacaoDraft = ref('');
const isSavingObservacao = ref(false);

const filesByCategoria = computed(() =>
  Object.fromEntries(
    FILE_CATEGORIAS.map(cat => [
      cat.value,
      files.value.filter(file => file.categoria === cat.value),
    ])
  )
);

const applyResponse = ({ data }) => {
  files.value = data.files || [];
};

const load = async () => {
  isLoading.value = true;
  isNotLinked.value = false;
  loadFailed.value = false;
  try {
    applyResponse(await CompanyAPI.listDocuments(props.companyId));
  } catch (error) {
    files.value = [];
    if (error.response?.status === 404) isNotLinked.value = true;
    else loadFailed.value = true;
  } finally {
    isLoading.value = false;
  }
};

const upload = async (categoria, event) => {
  const selected = Array.from(event.target.files || []);
  event.target.value = '';
  if (!selected.length) return;
  uploadingCategoria.value = categoria;
  try {
    await Promise.all(
      selected.map(file =>
        CompanyAPI.uploadDocument(props.companyId, categoria, file)
      )
    );
  } catch {
    useAlert(t('COMPANIES.DETAIL.DOCUMENTS.UPLOAD_ERROR'));
  } finally {
    uploadingCategoria.value = '';
    await load();
  }
};

const toggleObservacao = file => {
  if (editingFileId.value === file.id) {
    editingFileId.value = null;
    return;
  }
  editingFileId.value = file.id;
  observacaoDraft.value = file.observacao || '';
};

const saveObservacao = async file => {
  isSavingObservacao.value = true;
  try {
    applyResponse(
      await CompanyAPI.updateDocument(
        props.companyId,
        file.id,
        observacaoDraft.value
      )
    );
    editingFileId.value = null;
  } catch {
    useAlert(t('COMPANIES.DETAIL.DOCUMENTS.UPDATE_ERROR'));
  } finally {
    isSavingObservacao.value = false;
  }
};

const remove = async file => {
  try {
    applyResponse(await CompanyAPI.removeDocument(props.companyId, file.id));
  } catch {
    useAlert(t('COMPANIES.DETAIL.DOCUMENTS.REMOVE_ERROR'));
  }
};

// Download passa pelo axios (a sessão do Chatwoot vai no header, um link
// direto chegaria sem autenticação).
const download = async file => {
  try {
    const { data } = await CompanyAPI.downloadDocument(
      props.companyId,
      file.id
    );
    const url = URL.createObjectURL(data);
    const link = document.createElement('a');
    link.href = url;
    link.download = file.name;
    link.click();
    URL.revokeObjectURL(url);
  } catch {
    useAlert(t('COMPANIES.DETAIL.DOCUMENTS.DOWNLOAD_ERROR'));
  }
};

onMounted(load);
watch(() => props.companyId, load);
</script>

<template>
  <InfoCard
    :title="t('COMPANIES.DETAIL.DOCUMENTS.TITLE')"
    icon="i-lucide-paperclip"
  >
    <template #actions>
      <span />
    </template>
    <p v-if="isLoading" class="my-0 text-sm text-n-slate-11">
      {{ t('COMPANIES.DETAIL.LOADING') }}
    </p>
    <p v-else-if="isNotLinked" class="my-0 text-sm text-n-slate-11">
      {{ t('COMPANIES.DETAIL.DOCUMENTS.NOT_LINKED') }}
    </p>
    <p v-else-if="loadFailed" class="my-0 text-sm text-n-ruby-11">
      {{ t('COMPANIES.DETAIL.DOCUMENTS.LOAD_ERROR') }}
    </p>
    <div v-else class="flex flex-col gap-5">
      <div v-for="cat in FILE_CATEGORIAS" :key="cat.value">
        <p
          class="mt-0 mb-2 text-xs font-semibold tracking-wide uppercase text-n-slate-10"
        >
          {{ cat.label }}
        </p>
        <div
          v-if="filesByCategoria[cat.value].length"
          class="flex flex-col gap-1.5 mb-2"
        >
          <div
            v-for="file in filesByCategoria[cat.value]"
            :key="file.id"
            class="border rounded-lg w-fit max-w-full border-n-weak"
            :class="{ 'min-w-[18rem]': editingFileId === file.id }"
          >
            <div class="flex items-center justify-between gap-2 px-3 py-2">
              <button
                type="button"
                class="flex items-center min-w-0 gap-2 p-0 bg-transparent border-0 text-n-blue-11 hover:underline"
                @click="download(file)"
              >
                <Icon icon="i-lucide-paperclip" class="size-4 shrink-0" />
                <span class="text-sm font-medium truncate">{{
                  file.name
                }}</span>
              </button>
              <div class="flex items-center shrink-0">
                <Button
                  v-tooltip.top="t('COMPANIES.DETAIL.DOCUMENTS.OBSERVATION')"
                  icon="i-lucide-pencil"
                  ghost
                  slate
                  xs
                  @click="toggleObservacao(file)"
                />
                <Button
                  v-tooltip.top="t('COMPANIES.DETAIL.DOCUMENTS.REMOVE')"
                  icon="i-lucide-x"
                  ghost
                  ruby
                  xs
                  @click="remove(file)"
                />
              </div>
            </div>
            <div v-if="editingFileId === file.id" class="px-3 pb-3">
              <TextArea
                v-model="observacaoDraft"
                :placeholder="
                  t('COMPANIES.DETAIL.DOCUMENTS.OBSERVATION_PLACEHOLDER')
                "
                class="w-full"
                auto-height
              />
              <div class="flex items-center justify-end gap-2 mt-2">
                <Button
                  :label="t('COMPANIES.DETAIL.DOCUMENTS.CANCEL')"
                  ghost
                  slate
                  xs
                  @click="editingFileId = null"
                />
                <Button
                  :label="
                    isSavingObservacao
                      ? t('COMPANIES.DETAIL.DOCUMENTS.SAVING')
                      : t('COMPANIES.DETAIL.DOCUMENTS.SAVE')
                  "
                  :disabled="isSavingObservacao"
                  xs
                  @click="saveObservacao(file)"
                />
              </div>
            </div>
            <p
              v-else-if="file.observacao"
              class="px-3 pb-2 my-0 text-xs italic text-n-slate-11"
            >
              {{ file.observacao }}
            </p>
          </div>
        </div>
        <label
          class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium border rounded-lg cursor-pointer text-n-slate-12 border-n-weak hover:bg-n-alpha-2"
        >
          <Icon
            :icon="
              uploadingCategoria === cat.value
                ? 'i-lucide-loader-2'
                : 'i-lucide-plus'
            "
            class="size-4"
            :class="{ 'animate-spin': uploadingCategoria === cat.value }"
          />
          {{
            uploadingCategoria === cat.value
              ? t('COMPANIES.DETAIL.DOCUMENTS.UPLOADING')
              : t('COMPANIES.DETAIL.DOCUMENTS.ADD_FILE')
          }}
          <input
            type="file"
            multiple
            class="hidden"
            :disabled="!!uploadingCategoria"
            @change="upload(cat.value, $event)"
          />
        </label>
        <p
          v-if="!filesByCategoria[cat.value].length"
          class="mt-1 mb-0 text-xs text-n-slate-10"
        >
          {{ t('COMPANIES.DETAIL.DOCUMENTS.EMPTY') }}
        </p>
      </div>
    </div>
  </InfoCard>
</template>
