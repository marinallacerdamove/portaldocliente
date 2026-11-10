<script setup>
// PATCH LOCAL (fork) - "Novo grupo": pede só o nome. Quem usa cria o grupo (emit
// submit) e fecha o diálogo (close) quando o Portal aceitar; o erro do Portal
// (nome vazio ou repetido na conta) volta pelo errorMessage.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

defineProps({
  title: { type: String, required: true },
  confirmLabel: { type: String, required: true },
  errorMessage: { type: String, default: '' },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const dialogRef = ref(null);
const name = ref('');
const trimmedName = computed(() => name.value.trim());

const open = () => {
  name.value = '';
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const handleConfirm = () => {
  if (trimmedName.value) emit('submit', trimmedName.value);
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="title"
    :confirm-button-label="confirmLabel"
    :is-loading="isLoading"
    :disable-confirm-button="!trimmedName"
    @confirm="handleConfirm"
  >
    <Input
      v-model="name"
      :label="t('PORTAL_GROUPS.NAME_DIALOG.LABEL')"
      :placeholder="t('PORTAL_GROUPS.NAME_DIALOG.PLACEHOLDER')"
      :message="errorMessage"
      :message-type="errorMessage ? 'error' : 'info'"
      :disabled="isLoading"
      autofocus
    />
  </Dialog>
</template>
