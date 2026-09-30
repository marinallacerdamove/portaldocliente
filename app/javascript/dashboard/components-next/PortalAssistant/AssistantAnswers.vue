<script setup>
// PATCH LOCAL (fork) - aba "Respostas da equipe" do Assistente (só admin):
// respostas cadastradas à mão pro que a wiki não cobre. Sem excluir, só
// inativar (regra do painel).
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import PortalAssistantAPI from 'dashboard/api/portalAssistant';
import { usePortalAssistant } from 'dashboard/composables/usePortalAssistant';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';

const props = defineProps({
  // Pergunta sem resposta vinda da aba "Perguntas feitas", pra virar resposta.
  draftTitle: { type: String, default: '' },
});

const emit = defineEmits(['draftConsumed']);

const { t } = useI18n();
const { formatDate, errorMessage } = usePortalAssistant();

const answers = ref([]);
const meta = ref({ page: 1, per_page: 20, total: 0 });
const isLoading = ref(true);
const loadError = ref('');
const isSaving = ref(false);
// null = formulário fechado; {} = nova; { id, ... } = editando.
const form = ref(null);

const isFormValid = computed(
  () => form.value?.title?.trim() && form.value?.content?.trim()
);

const load = async (page = meta.value.page) => {
  isLoading.value = true;
  loadError.value = '';
  try {
    const { data } = await PortalAssistantAPI.getAnswers(page);
    answers.value = data.data;
    meta.value = data.meta;
  } catch (error) {
    loadError.value = errorMessage(
      error,
      t('PORTAL_ASSISTANT.ANSWERS.LOAD_ERROR')
    );
  } finally {
    isLoading.value = false;
  }
};

const openNew = (title = '') => {
  form.value = { title, content: '' };
};

const openEdit = answer => {
  form.value = { id: answer.id, title: answer.title, content: answer.content };
};

const closeForm = () => {
  form.value = null;
};

const save = async () => {
  if (!isFormValid.value) return;
  isSaving.value = true;
  const { id, title, content } = form.value;
  try {
    if (id) await PortalAssistantAPI.updateAnswer(id, { title, content });
    else await PortalAssistantAPI.createAnswer({ title, content });
    useAlert(t('PORTAL_ASSISTANT.ANSWERS.SAVED'));
    closeForm();
    await load(id ? meta.value.page : 1);
  } catch (error) {
    const serverErrors = error?.response?.data?.errors;
    useAlert(
      serverErrors?.join(', ') ||
        errorMessage(error, t('PORTAL_ASSISTANT.ANSWERS.SAVE_ERROR'))
    );
  } finally {
    isSaving.value = false;
  }
};

const toggleActive = async answer => {
  try {
    const { data } = await PortalAssistantAPI.updateAnswer(answer.id, {
      active: !answer.active,
    });
    Object.assign(answer, data);
  } catch (error) {
    useAlert(errorMessage(error, t('PORTAL_ASSISTANT.ANSWERS.SAVE_ERROR')));
  }
};

watch(
  () => props.draftTitle,
  title => {
    if (!title) return;
    openNew(title);
    emit('draftConsumed');
  },
  { immediate: true }
);

onMounted(() => load(1));
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-start justify-between gap-3">
      <p class="mb-0 text-sm text-n-slate-11">
        {{ t('PORTAL_ASSISTANT.ANSWERS.HINT') }}
      </p>
      <Button
        v-if="!form"
        :label="t('PORTAL_ASSISTANT.ANSWERS.NEW')"
        icon="i-lucide-plus"
        sm
        class="shrink-0"
        @click="openNew()"
      />
    </div>

    <InfoCard
      v-if="form"
      :title="
        form.id
          ? t('PORTAL_ASSISTANT.ANSWERS.EDIT')
          : t('PORTAL_ASSISTANT.ANSWERS.NEW')
      "
      icon="i-lucide-message-square-plus"
      is-editing
      :is-saving="isSaving"
      :save-disabled="!isFormValid"
      @cancel="closeForm"
      @save="save"
    >
      <template #edit>
        <div class="flex flex-col gap-3">
          <Input
            id="portal-assistant-answer-title"
            v-model="form.title"
            :label="t('PORTAL_ASSISTANT.ANSWERS.TITLE_LABEL')"
            :placeholder="t('PORTAL_ASSISTANT.ANSWERS.TITLE_PLACEHOLDER')"
          />
          <label
            for="portal-assistant-answer-content"
            class="flex flex-col gap-1 mb-0 text-sm font-medium text-n-slate-12"
          >
            {{ t('PORTAL_ASSISTANT.ANSWERS.CONTENT_LABEL') }}
            <textarea
              id="portal-assistant-answer-content"
              v-model="form.content"
              rows="8"
              :placeholder="t('PORTAL_ASSISTANT.ANSWERS.CONTENT_PLACEHOLDER')"
              class="w-full px-3 py-2 mb-0 text-sm font-normal border rounded-lg resize-y border-n-weak bg-n-alpha-black2 text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
            />
          </label>
        </div>
      </template>
    </InfoCard>

    <div v-if="isLoading" class="flex py-8">
      <Spinner :size="16" />
    </div>

    <p v-else-if="loadError" class="mb-0 text-sm text-n-ruby-11">
      {{ loadError }}
    </p>

    <p v-else-if="!answers.length" class="mb-0 text-sm text-n-slate-10">
      {{ t('PORTAL_ASSISTANT.ANSWERS.EMPTY') }}
    </p>

    <template v-else>
      <article
        v-for="answer in answers"
        :key="answer.id"
        class="flex flex-col gap-2 p-4 border shadow-sm rounded-xl border-n-weak bg-n-solid-1"
        :class="{ 'opacity-60': !answer.active }"
      >
        <div class="flex items-start justify-between gap-3">
          <p class="mb-0 text-sm font-semibold text-n-slate-12">
            {{ answer.title }}
          </p>
          <div class="flex items-center gap-1 shrink-0">
            <Button
              v-tooltip.top="t('PORTAL_ASSISTANT.ANSWERS.EDIT')"
              icon="i-lucide-pencil"
              ghost
              slate
              xs
              @click="openEdit(answer)"
            />
            <Button
              :label="
                answer.active
                  ? t('PORTAL_ASSISTANT.ANSWERS.DEACTIVATE')
                  : t('PORTAL_ASSISTANT.ANSWERS.ACTIVATE')
              "
              ghost
              slate
              xs
              @click="toggleActive(answer)"
            />
          </div>
        </div>
        <p
          class="mb-0 text-sm whitespace-pre-line line-clamp-4 text-n-slate-11"
        >
          {{ answer.content }}
        </p>
        <div class="flex flex-wrap items-center gap-2 text-xs text-n-slate-10">
          <span
            class="px-2 py-0.5 rounded-md"
            :class="
              answer.active
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-alpha-2 text-n-slate-11'
            "
          >
            {{
              answer.active
                ? t('PORTAL_ASSISTANT.ANSWERS.ACTIVE')
                : t('PORTAL_ASSISTANT.ANSWERS.INACTIVE')
            }}
          </span>
          <span v-if="answer.active">
            {{
              answer.indexed
                ? t('PORTAL_ASSISTANT.ANSWERS.INDEXED')
                : t('PORTAL_ASSISTANT.ANSWERS.NOT_INDEXED')
            }}
          </span>
          <span>{{ formatDate(answer.updated_at) }}</span>
        </div>
      </article>

      <PaginationFooter
        v-if="meta.total > meta.per_page"
        :current-page="meta.page"
        :total-items="meta.total"
        :items-per-page="meta.per_page"
        @update:current-page="load"
      />
    </template>
  </div>
</template>
