<script setup>
// PATCH LOCAL (fork) - aba "Perguntas feitas" do Assistente (só admin): o que
// os atendentes perguntaram. "Sem resposta" e "avaliadas como ruins" mostram
// o que falta na base; cada pergunta pode virar uma resposta da equipe.
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import PortalAssistantAPI from 'dashboard/api/portalAssistant';
import { usePortalAssistant } from 'dashboard/composables/usePortalAssistant';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';

const emit = defineEmits(['createAnswer']);

const FILTERS = ['unanswered', 'rated_down', 'all'];

const { t } = useI18n();
const { formatDate, errorMessage } = usePortalAssistant();

const filter = ref(FILTERS[0]);
const questions = ref([]);
const meta = ref({ page: 1, per_page: 20, total: 0 });
const isLoading = ref(true);
const loadError = ref('');

const load = async (page = 1) => {
  isLoading.value = true;
  loadError.value = '';
  try {
    const { data } = await PortalAssistantAPI.getQuestions({
      filter: filter.value,
      page,
    });
    questions.value = data.data;
    meta.value = data.meta;
  } catch (error) {
    loadError.value = errorMessage(
      error,
      t('PORTAL_ASSISTANT.QUESTIONS.LOAD_ERROR')
    );
  } finally {
    isLoading.value = false;
  }
};

const selectFilter = value => {
  filter.value = value;
  load(1);
};

const statusChip = question => {
  if (question.failed) {
    return {
      label: t('PORTAL_ASSISTANT.QUESTIONS.FAILED'),
      class: 'bg-n-ruby-3 text-n-ruby-11',
    };
  }
  if (question.answered) {
    return {
      label: t('PORTAL_ASSISTANT.QUESTIONS.ANSWERED'),
      class: 'bg-n-teal-3 text-n-teal-11',
    };
  }
  return {
    label: t('PORTAL_ASSISTANT.QUESTIONS.UNANSWERED'),
    class: 'bg-n-amber-3 text-n-amber-11',
  };
};

onMounted(() => load(1));
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex flex-wrap gap-2">
      <Button
        v-for="value in FILTERS"
        :key="value"
        :label="t(`PORTAL_ASSISTANT.QUESTIONS.FILTERS.${value}`)"
        :variant="filter === value ? 'solid' : 'faded'"
        :color="filter === value ? 'blue' : 'slate'"
        xs
        @click="selectFilter(value)"
      />
    </div>

    <div v-if="isLoading" class="flex py-8">
      <Spinner :size="16" />
    </div>

    <p v-else-if="loadError" class="mb-0 text-sm text-n-ruby-11">
      {{ loadError }}
    </p>

    <p v-else-if="!questions.length" class="mb-0 text-sm text-n-slate-10">
      {{ t('PORTAL_ASSISTANT.QUESTIONS.EMPTY') }}
    </p>

    <template v-else>
      <article
        v-for="question in questions"
        :key="question.id"
        class="flex flex-col gap-2 p-4 border shadow-sm rounded-xl border-n-weak bg-n-solid-1"
      >
        <div class="flex items-start justify-between gap-3">
          <p class="mb-0 text-sm font-semibold text-n-slate-12">
            {{ question.question }}
          </p>
          <Button
            v-if="!question.answered || question.rating === 'down'"
            :label="t('PORTAL_ASSISTANT.QUESTIONS.CREATE_ANSWER')"
            icon="i-lucide-message-square-plus"
            faded
            slate
            xs
            class="shrink-0"
            @click="emit('createAnswer', question.question)"
          />
        </div>
        <p
          v-if="question.answer"
          class="mb-0 text-sm whitespace-pre-line line-clamp-3 text-n-slate-11"
        >
          {{ question.answer }}
        </p>
        <div class="flex flex-wrap items-center gap-2 text-xs text-n-slate-10">
          <span
            class="px-2 py-0.5 rounded-md"
            :class="statusChip(question).class"
          >
            {{ statusChip(question).label }}
          </span>
          <span
            v-if="question.rating"
            class="px-2 py-0.5 rounded-md bg-n-alpha-2 text-n-slate-11"
          >
            {{
              question.rating === 'up'
                ? t('PORTAL_ASSISTANT.QUESTIONS.RATED_UP')
                : t('PORTAL_ASSISTANT.QUESTIONS.RATED_DOWN')
            }}
          </span>
          <span>
            {{
              t('PORTAL_ASSISTANT.QUESTIONS.BY', {
                name: question.user_name || '',
                date: formatDate(question.created_at),
              })
            }}
          </span>
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
