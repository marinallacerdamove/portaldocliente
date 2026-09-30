<script setup>
// PATCH LOCAL (fork) - aba "Perguntar" do Assistente: o atendente pergunta, a
// resposta vem da base de conhecimento (wiki + respostas da equipe) no Portal.
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  MAX_QUESTION_LENGTH,
  usePortalAssistantAsk,
} from 'dashboard/composables/usePortalAssistantAsk';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import AssistantAnswerCard from './AssistantAnswerCard.vue';

const { t } = useI18n();
const { isAsking, ask } = usePortalAssistantAsk();

const question = ref('');
// Respostas desta sessão, a mais recente primeiro.
const history = ref([]);

const submit = async () => {
  const answer = await ask(question.value);
  if (!answer) return;
  history.value.unshift(answer);
  question.value = '';
};

const onKeydown = event => {
  if (event.key !== 'Enter' || event.shiftKey) return;
  event.preventDefault();
  submit();
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <div
      class="flex flex-col gap-2 p-4 border shadow-sm rounded-xl border-n-weak bg-n-solid-1"
    >
      <textarea
        id="portal-assistant-question"
        v-model="question"
        rows="3"
        :maxlength="MAX_QUESTION_LENGTH"
        :placeholder="t('PORTAL_ASSISTANT.ASK.PLACEHOLDER')"
        :disabled="isAsking"
        class="w-full px-3 py-2 mb-0 text-sm border rounded-lg resize-y border-n-weak bg-n-alpha-black2 text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
        @keydown="onKeydown"
      />
      <div class="flex items-center justify-between gap-2">
        <span class="text-xs text-n-slate-10">
          {{ t('PORTAL_ASSISTANT.ASK.HINT') }}
        </span>
        <Button
          :label="t('PORTAL_ASSISTANT.ASK.SUBMIT')"
          icon="i-lucide-send"
          sm
          :is-loading="isAsking"
          :disabled="!question.trim() || isAsking"
          @click="submit"
        />
      </div>
    </div>

    <div
      v-if="isAsking"
      class="flex items-center gap-2 px-1 text-sm text-n-slate-11"
    >
      <Spinner :size="16" />
      {{ t('PORTAL_ASSISTANT.ASK.THINKING') }}
    </div>

    <div
      v-if="!history.length && !isAsking"
      class="flex flex-col gap-1 p-4 border border-dashed rounded-xl border-n-weak"
    >
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('PORTAL_ASSISTANT.ASK.EMPTY_TITLE') }}
      </span>
      <p class="mb-0 text-sm text-n-slate-11">
        {{ t('PORTAL_ASSISTANT.ASK.EMPTY_TEXT') }}
      </p>
    </div>

    <AssistantAnswerCard
      v-for="item in history"
      :key="item.id"
      :item="item"
      class="p-4 border shadow-sm rounded-xl border-n-weak bg-n-solid-1"
    />
  </div>
</template>
