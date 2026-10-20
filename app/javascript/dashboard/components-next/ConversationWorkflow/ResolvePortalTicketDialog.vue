<script setup>
// PATCH LOCAL (fork) - "Criar ticket desta conversa no Portal?" ao encerrar uma
// conversa de WhatsApp. ask() devolve true (Sim), false (Não) ou null (fechou no
// X/Esc/fora: não encerra nada).
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();

const dialogRef = ref(null);
const contactName = ref('');
let settle = null;

const finish = answer => {
  const resolve = settle;
  settle = null;
  dialogRef.value?.close();
  resolve?.(answer);
};

// O close do Dialog dispara também depois de finish: só vale se ainda não respondeu.
const onClose = () => finish(null);

const ask = (name = '') =>
  new Promise(resolve => {
    contactName.value = name;
    settle = resolve;
    dialogRef.value?.open();
  });

defineExpose({ ask });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('CONVERSATION.PORTAL_TICKET_OFFER.TITLE')"
    :description="
      t('CONVERSATION.PORTAL_TICKET_OFFER.DESCRIPTION', { name: contactName })
    "
    show-close-button
    width="md"
    @close="onClose"
  >
    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <Button
          variant="faded"
          color="slate"
          :label="t('CONVERSATION.PORTAL_TICKET_OFFER.NO')"
          class="w-full"
          type="button"
          @click="finish(false)"
        />
        <Button
          color="blue"
          :label="t('CONVERSATION.PORTAL_TICKET_OFFER.YES')"
          class="w-full"
          type="button"
          @click="finish(true)"
        />
      </div>
    </template>
  </Dialog>
</template>
