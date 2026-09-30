<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useMessageEditing } from 'dashboard/composables/useMessageEditing';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { editingMessage, stopEditing } = useMessageEditing();
const { t } = useI18n();
const store = useStore();

const draft = ref('');
const saving = ref(false);
const fileInputRef = ref(null);
const newAttachments = ref([]);
const removedAttachmentIds = ref([]);

// Reidrata o rascunho toda vez que uma mensagem diferente entra em edição -
// `editingMessage` é o mesmo objeto enquanto o usuário edita (mutado só por
// stopEditing/startEditing), então observar o id é suficiente.
watch(
  () => editingMessage.value?.id,
  id => {
    if (!id) return;
    draft.value = editingMessage.value.content || '';
    newAttachments.value = [];
    removedAttachmentIds.value = [];
  },
  { immediate: true }
);

const existingAttachments = computed(() =>
  (editingMessage.value?.attachments || []).filter(
    attachment => !removedAttachmentIds.value.includes(attachment.id)
  )
);

const title = computed(() =>
  editingMessage.value?.senderName
    ? t('CONVERSATION.MESSAGE_EDIT_BAR.TITLE_WITH_SENDER', {
        name: editingMessage.value.senderName,
      })
    : t('CONVERSATION.MESSAGE_EDIT_BAR.TITLE')
);

// Chatwoot não guarda o nome original do arquivo no attachment (só
// data_url/extension - ver _attachment.json.jbuilder) - mas url_for(file)
// do ActiveStorage sempre termina o path com o filename original, então dá
// pra recuperar um nome legível sem mudar o backend.
function attachmentLabel(attachment) {
  const fromUrl = attachment.dataUrl?.split('/').pop()?.split('?')[0];
  if (fromUrl && fromUrl.includes('.')) return decodeURIComponent(fromUrl);
  return attachment.extension
    ? `${t('CONVERSATION.UNKNOWN_FILE_TYPE')}.${attachment.extension}`
    : t('CONVERSATION.UNKNOWN_FILE_TYPE');
}

function removeExistingAttachment(id) {
  removedAttachmentIds.value.push(id);
}

function removeNewAttachment(index) {
  newAttachments.value.splice(index, 1);
}

function openFilePicker() {
  fileInputRef.value?.click();
}

function onFilesSelected(event) {
  newAttachments.value.push(...Array.from(event.target.files || []));
  event.target.value = '';
}

function cancel() {
  stopEditing();
}

async function save() {
  const trimmed = draft.value.trim();
  if (!trimmed) {
    useAlert(t('CONVERSATION.MESSAGE_EDIT_BAR.EMPTY_ERROR'));
    return;
  }

  saving.value = true;
  try {
    await store.dispatch('editMessage', {
      conversationId: editingMessage.value.conversationId,
      messageId: editingMessage.value.id,
      content: trimmed,
      attachments: newAttachments.value,
      removeAttachmentIds: removedAttachmentIds.value,
    });
    stopEditing();
  } catch (error) {
    useAlert(t('CONVERSATION.MESSAGE_EDIT_BAR.ERROR'));
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div
    class="flex relative flex-col mx-2 mb-2 rounded-xl border bg-n-solid-1 border-n-weak"
  >
    <div
      class="flex gap-2 justify-between items-center px-4 py-2 rounded-t-xl border-b border-n-weak bg-n-solid-2"
    >
      <div
        class="flex gap-2 items-center min-w-0 text-sm font-medium text-n-slate-12"
      >
        <Icon icon="i-lucide-pencil-line" class="shrink-0 size-4" />
        <span class="truncate">{{ title }}</span>
      </div>
      <button
        type="button"
        class="text-sm text-n-slate-11 hover:text-n-slate-12"
        :disabled="saving"
        @click="cancel"
      >
        {{ $t('CONVERSATION.MESSAGE_EDIT_BAR.CANCEL') }}
      </button>
    </div>
    <div class="flex flex-col gap-3 px-4 py-3">
      <WootMessageEditor
        v-model="draft"
        :placeholder="$t('CONVERSATION.MESSAGE_EDIT_BAR.PLACEHOLDER')"
        :disabled="saving"
        :enable-suggestions="false"
        :enable-canned-responses="false"
        focus-on-mount
      />
      <div
        v-if="existingAttachments.length || newAttachments.length"
        class="flex flex-wrap gap-2"
      >
        <div
          v-for="attachment in existingAttachments"
          :key="`existing-${attachment.id}`"
          class="flex gap-1 items-center py-1 pr-1 pl-2 text-xs rounded-md bg-n-slate-3 text-n-slate-12"
        >
          <Icon icon="i-lucide-paperclip" class="shrink-0 size-3" />
          <span class="max-w-[10rem] truncate">
            {{ attachmentLabel(attachment) }}
          </span>
          <button
            type="button"
            class="flex items-center rounded hover:bg-n-slate-4"
            :disabled="saving"
            @click="removeExistingAttachment(attachment.id)"
          >
            <Icon icon="i-lucide-x" class="size-3" />
          </button>
        </div>
        <div
          v-for="(file, index) in newAttachments"
          :key="`new-${file.name}-${index}`"
          class="flex gap-1 items-center py-1 pr-1 pl-2 text-xs rounded-md bg-n-solid-amber text-n-amber-12"
        >
          <Icon icon="i-lucide-paperclip" class="shrink-0 size-3" />
          <span class="max-w-[10rem] truncate">{{ file.name }}</span>
          <button
            type="button"
            class="flex items-center rounded hover:bg-n-amber-4"
            :disabled="saving"
            @click="removeNewAttachment(index)"
          >
            <Icon icon="i-lucide-x" class="size-3" />
          </button>
        </div>
      </div>
      <div class="flex justify-between items-center">
        <button
          type="button"
          class="flex gap-1.5 items-center text-sm text-n-slate-11 hover:text-n-slate-12"
          :disabled="saving"
          @click="openFilePicker"
        >
          <Icon icon="i-lucide-paperclip" class="size-4" />
          {{ $t('CONVERSATION.MESSAGE_EDIT_BAR.ADD_ATTACHMENT') }}
        </button>
        <input
          ref="fileInputRef"
          type="file"
          multiple
          class="hidden"
          @change="onFilesSelected"
        />
        <NextButton
          :label="$t('CONVERSATION.MESSAGE_EDIT_BAR.SAVE')"
          sm
          :is-loading="saving"
          :disabled="!draft.trim() || saving"
          @click="save"
        />
      </div>
    </div>
  </div>
</template>
