<script setup>
// PATCH LOCAL (fork) - lápis do grupo na lista: trocar o nome e ativar ou
// inativar. Quem usa grava (emit submit) e fecha o diálogo (close) quando o
// Portal aceitar; o erro do Portal (nome vazio ou repetido na conta) volta
// pelo errorMessage.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

defineProps({
  errorMessage: { type: String, default: '' },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const dialogRef = ref(null);
const name = ref('');
const active = ref(true);
const trimmedName = computed(() => name.value.trim());

const open = group => {
  name.value = group.name;
  active.value = group.active;
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const handleConfirm = () => {
  if (trimmedName.value) {
    emit('submit', { name: trimmedName.value, active: active.value });
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('PORTAL_GROUPS.EDIT.TITLE')"
    :confirm-button-label="t('PORTAL_GROUPS.EDIT.SUBMIT')"
    :is-loading="isLoading"
    :disable-confirm-button="!trimmedName"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-4">
      <Input
        v-model="name"
        :label="t('PORTAL_GROUPS.NAME_DIALOG.LABEL')"
        :placeholder="t('PORTAL_GROUPS.NAME_DIALOG.PLACEHOLDER')"
        :message="errorMessage"
        :message-type="errorMessage ? 'error' : 'info'"
        :disabled="isLoading"
        autofocus
      />
      <label class="flex items-start gap-3">
        <Switch v-model="active" :disabled="isLoading" class="mt-0.5" />
        <span class="flex flex-col gap-0.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('PORTAL_GROUPS.EDIT.ACTIVE') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('PORTAL_GROUPS.EDIT.ACTIVE_HINT') }}
          </span>
        </span>
      </label>
    </div>
  </Dialog>
</template>
