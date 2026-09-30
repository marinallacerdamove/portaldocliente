<script setup>
// PATCH LOCAL (fork) - resposta do Assistente: texto (ou "não encontrei"),
// fontes e ações (copiar, avaliar). Slot #actions pra ações extras (ex.
// "Inserir na resposta" no editor da conversa).
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import {
  RATINGS,
  usePortalAssistantAsk,
} from 'dashboard/composables/usePortalAssistantAsk';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  item: { type: Object, required: true },
  showQuestion: { type: Boolean, default: true },
});

const { t } = useI18n();
const { rate } = usePortalAssistantAsk();

const copyAnswer = async () => {
  await copyTextToClipboard(props.item.answer);
  useAlert(t('PORTAL_ASSISTANT.ASK.COPIED'));
};
</script>

<template>
  <article class="flex flex-col gap-3">
    <p v-if="showQuestion" class="mb-0 text-sm font-semibold text-n-slate-12">
      {{ item.question }}
    </p>

    <p
      v-if="item.answered"
      class="mb-0 text-sm leading-relaxed whitespace-pre-line text-n-slate-12"
    >
      {{ item.answer }}
    </p>
    <p v-else class="flex items-start gap-2 mb-0 text-sm text-n-amber-11">
      <Icon icon="i-lucide-circle-help" class="size-4 mt-0.5 shrink-0" />
      {{ t('PORTAL_ASSISTANT.ASK.NOT_FOUND') }}
    </p>

    <div v-if="item.sources.length" class="flex flex-col gap-1.5">
      <span class="text-xs font-medium text-n-slate-11">
        {{ t('PORTAL_ASSISTANT.ASK.SOURCES') }}
      </span>
      <div class="flex flex-wrap gap-1.5">
        <template v-for="source in item.sources" :key="source.id">
          <a
            v-if="source.url"
            :href="source.url"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-blue-11 hover:underline"
          >
            <Icon icon="i-lucide-book-open" class="size-3" />
            {{ source.title }}
          </a>
          <span
            v-else
            class="inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-12"
          >
            <Icon icon="i-lucide-users" class="size-3" />
            {{ t('PORTAL_ASSISTANT.ASK.TEAM_ANSWER', { title: source.title }) }}
          </span>
        </template>
      </div>
    </div>

    <div
      v-if="item.answered"
      class="flex items-center gap-1 pt-2 border-t border-n-weak"
    >
      <slot name="actions" />
      <Button
        v-tooltip.top="t('PORTAL_ASSISTANT.ASK.COPY')"
        icon="i-lucide-copy"
        ghost
        slate
        xs
        @click="copyAnswer"
      />
      <Button
        v-tooltip.top="t('PORTAL_ASSISTANT.ASK.HELPFUL')"
        icon="i-lucide-thumbs-up"
        :color="item.rating === RATINGS.UP ? 'teal' : 'slate'"
        ghost
        xs
        @click="rate(item, RATINGS.UP)"
      />
      <Button
        v-tooltip.top="t('PORTAL_ASSISTANT.ASK.NOT_HELPFUL')"
        icon="i-lucide-thumbs-down"
        :color="item.rating === RATINGS.DOWN ? 'ruby' : 'slate'"
        ghost
        xs
        @click="rate(item, RATINGS.DOWN)"
      />
    </div>
  </article>
</template>
