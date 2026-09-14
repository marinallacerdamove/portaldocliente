<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import BaseBubble from 'next/message/bubbles/Base.vue';
import FormattedContent from './FormattedContent.vue';
import AttachmentChips from 'next/message/chips/AttachmentChips.vue';
import TranslationToggle from 'dashboard/components-next/message/TranslationToggle.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { MESSAGE_TYPES } from '../../constants';
import { useMessageContext } from '../../provider.js';
import { useTranslations } from 'dashboard/composables/useTranslations';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

const {
  content,
  attachments,
  contentAttributes,
  messageType,
  id,
  conversationId,
  isEditing,
} = useMessageContext();

const { hasTranslations, translationContent } =
  useTranslations(contentAttributes);

const { t } = useI18n();
const store = useStore();

const editDraft = ref('');
const savingEdit = ref(false);

watch(isEditing, editing => {
  if (editing) editDraft.value = content.value;
});

async function saveEdit() {
  const trimmed = editDraft.value.trim();
  if (!trimmed) return;

  savingEdit.value = true;
  try {
    await store.dispatch('editMessage', {
      conversationId: conversationId.value,
      messageId: id.value,
      content: trimmed,
    });
    isEditing.value = false;
  } catch (error) {
    useAlert(t('CONVERSATION.FAIL_EDIT_MESSAGE'));
  } finally {
    savingEdit.value = false;
  }
}

function cancelEdit() {
  isEditing.value = false;
}

const renderOriginal = ref(false);

const renderContent = computed(() => {
  if (renderOriginal.value) {
    return content.value;
  }

  if (hasTranslations.value) {
    return translationContent.value;
  }

  return content.value;
});

const isTemplate = computed(() => {
  return messageType.value === MESSAGE_TYPES.TEMPLATE;
});

const isEmpty = computed(() => {
  return !content.value && !attachments.value?.length;
});

const handleSeeOriginal = () => {
  renderOriginal.value = !renderOriginal.value;
};
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="text">
    <div v-if="isEditing" class="gap-2 flex flex-col min-w-64">
      <TextArea v-model="editDraft" auto-height :disabled="savingEdit" />
      <div class="flex items-center justify-end gap-2">
        <NextButton
          :label="$t('CONVERSATION.CONTEXT_MENU.EDIT_MESSAGE.CANCEL')"
          ghost
          slate
          sm
          :disabled="savingEdit"
          @click="cancelEdit"
        />
        <NextButton
          :label="$t('CONVERSATION.CONTEXT_MENU.EDIT_MESSAGE.SAVE')"
          sm
          :is-loading="savingEdit"
          :disabled="!editDraft.trim() || savingEdit"
          @click="saveEdit"
        />
      </div>
    </div>
    <div v-else class="gap-3 flex flex-col">
      <span v-if="isEmpty" class="text-n-slate-11">
        {{ $t('CONVERSATION.NO_CONTENT') }}
      </span>
      <FormattedContent v-if="renderContent" :content="renderContent" />
      <span v-if="contentAttributes.editedAt" class="text-xs text-n-slate-11">
        {{ $t('CONVERSATION.EDITED') }}
      </span>
      <TranslationToggle
        v-if="hasTranslations"
        class="-mt-3"
        :showing-original="renderOriginal"
        @toggle="handleSeeOriginal"
      />
      <AttachmentChips :attachments="attachments" class="gap-2" />
      <template v-if="isTemplate">
        <div
          v-if="contentAttributes.submittedEmail"
          class="px-2 py-1 rounded-lg bg-n-alpha-3"
        >
          {{ contentAttributes.submittedEmail }}
        </div>
      </template>
    </div>
  </BaseBubble>
</template>

<style>
p:last-child {
  margin-bottom: 0;
}
</style>
