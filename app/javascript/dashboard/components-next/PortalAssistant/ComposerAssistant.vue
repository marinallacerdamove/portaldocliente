<script setup>
// PATCH LOCAL (fork) - Assistente dentro do editor de resposta da conversa
// (mesmo lugar do Copilot): pergunta já vem com a última mensagem do cliente,
// e a resposta pode ser inserida direto no editor.
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { useMapGetter } from 'dashboard/composables/store';
import {
  MAX_QUESTION_LENGTH,
  usePortalAssistantAsk,
} from 'dashboard/composables/usePortalAssistantAsk';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import AssistantAnswerCard from './AssistantAnswerCard.vue';

defineProps({
  disabled: { type: Boolean, default: false },
});

const { t } = useI18n();
const { isAsking, ask } = usePortalAssistantAsk();
const currentChat = useMapGetter('getSelectedChat');
const inboxGetter = useMapGetter('inboxes/getInbox');

const isOpen = ref(false);
const toggleRef = ref(null);
const question = ref('');
const result = ref(null);

const lastCustomerMessage = computed(() => {
  const messages = currentChat.value?.messages || [];
  const last = [...messages]
    .reverse()
    .find(
      message =>
        message.message_type === MESSAGE_TYPE.INCOMING &&
        !message.private &&
        message.content
    );
  return (last?.content || '').slice(0, MAX_QUESTION_LENGTH);
});

// Web e e-mail usam o editor rico (markdown); o resto, texto puro.
const insertIntoRichEditor = computed(() => {
  const inbox = inboxGetter.value(currentChat.value?.inbox_id);
  return [INBOX_TYPES.WEB, INBOX_TYPES.EMAIL].includes(inbox?.channel_type);
});

const toggle = () => {
  isOpen.value = !isOpen.value;
  if (isOpen.value && !question.value.trim()) {
    question.value = lastCustomerMessage.value;
  }
};

const close = () => {
  isOpen.value = false;
};

const submit = async () => {
  const answer = await ask(question.value);
  if (answer) result.value = answer;
};

const onKeydown = event => {
  if (event.key === 'Escape') close();
  if (event.key !== 'Enter' || event.shiftKey) return;
  event.preventDefault();
  submit();
};

const newQuestion = () => {
  result.value = null;
  question.value = '';
};

const insertAnswer = () => {
  const event = insertIntoRichEditor.value
    ? BUS_EVENTS.INSERT_INTO_RICH_EDITOR
    : BUS_EVENTS.INSERT_INTO_NORMAL_EDITOR;
  emitter.emit(event, result.value.answer);
  close();
};

// Outra conversa: pergunta e resposta da anterior não valem mais.
watch(
  () => currentChat.value?.id,
  () => {
    close();
    newQuestion();
  }
);
</script>

<template>
  <div class="relative">
    <Button
      ref="toggleRef"
      v-tooltip.top="t('PORTAL_ASSISTANT.COMPOSER.TOOLTIP')"
      ghost
      sm
      icon="i-lucide-book-open-check"
      :disabled="disabled"
      :class="isOpen ? 'text-n-blue-11 bg-n-alpha-2' : 'text-n-blue-11'"
      @click="toggle"
    />
    <div
      v-if="isOpen"
      v-on-click-outside="[close, { ignore: [toggleRef] }]"
      class="absolute z-50 flex flex-col w-[26rem] max-w-[calc(100vw-2rem)] max-h-[60vh] gap-3 p-4 mb-2 overflow-y-auto border shadow-lg ltr:right-0 rtl:left-0 bottom-full rounded-xl border-n-weak bg-n-solid-1"
    >
      <div class="flex flex-col gap-0.5">
        <span class="text-sm font-semibold text-n-slate-12">
          {{ t('PORTAL_ASSISTANT.COMPOSER.TITLE') }}
        </span>
        <span class="text-xs text-n-slate-10">
          {{ t('PORTAL_ASSISTANT.COMPOSER.HINT') }}
        </span>
      </div>

      <template v-if="!result">
        <textarea
          id="portal-assistant-composer-question"
          v-model="question"
          rows="4"
          :maxlength="MAX_QUESTION_LENGTH"
          :placeholder="t('PORTAL_ASSISTANT.ASK.PLACEHOLDER')"
          :disabled="isAsking"
          class="w-full px-3 py-2 mb-0 text-sm border rounded-lg resize-y border-n-weak bg-n-alpha-black2 text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
          @keydown="onKeydown"
        />
        <div class="flex items-center justify-between gap-2">
          <span
            v-if="isAsking"
            class="flex items-center gap-2 text-xs text-n-slate-11"
          >
            <Spinner :size="14" />
            {{ t('PORTAL_ASSISTANT.ASK.THINKING') }}
          </span>
          <span v-else class="text-xs text-n-slate-10">
            {{ t('PORTAL_ASSISTANT.ASK.HINT') }}
          </span>
          <Button
            :label="t('PORTAL_ASSISTANT.ASK.SUBMIT')"
            icon="i-lucide-send"
            xs
            :is-loading="isAsking"
            :disabled="!question.trim() || isAsking"
            @click="submit"
          />
        </div>
      </template>

      <template v-else>
        <AssistantAnswerCard :item="result">
          <template #actions>
            <Button
              :label="t('PORTAL_ASSISTANT.COMPOSER.INSERT')"
              icon="i-lucide-corner-down-left"
              xs
              class="ltr:mr-auto rtl:ml-auto"
              @click="insertAnswer"
            />
          </template>
        </AssistantAnswerCard>
        <Button
          :label="t('PORTAL_ASSISTANT.COMPOSER.NEW_QUESTION')"
          icon="i-lucide-rotate-ccw"
          ghost
          slate
          xs
          class="self-start"
          @click="newQuestion"
        />
      </template>
    </div>
  </div>
</template>
