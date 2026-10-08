<script setup>
// PATCH LOCAL (fork) - barra de ações do contato (nova mensagem, ligar, editar,
// mesclar, excluir), a mesma nos dois cabeçalhos do ContactInfo (com e sem
// empresa).
import { useMapGetter } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import ContactMergeModal from 'dashboard/modules/contact/ContactMergeModal.vue';
import ContactDeleteModal from 'dashboard/modules/contact/ContactDeleteModal.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import VoiceCallButton from 'dashboard/components-next/Contacts/VoiceCallButton.vue';

defineProps({
  contact: { type: Object, required: true },
  conversationId: { type: [Number, String], default: undefined },
});
const emit = defineEmits(['edit', 'deleted']);

const { isAdmin } = useAdmin();
const uiFlags = useMapGetter('contacts/getUIFlags');
</script>

<template>
  <div class="flex items-center gap-2">
    <ComposeConversation :contact-id="String(contact.id)">
      <template #trigger>
        <NextButton
          v-tooltip.top-end="$t('CONTACT_PANEL.NEW_MESSAGE')"
          icon="i-ph-chat-circle-dots"
          slate
          faded
          sm
        />
      </template>
    </ComposeConversation>
    <VoiceCallButton
      :phone="contact.phone_number"
      :contact-id="contact.id"
      :conversation-id="conversationId"
      icon="i-lucide-phone"
      sm
      faded
      slate
      :tooltip-label="$t('CONTACT_PANEL.CALL')"
    />
    <NextButton
      v-tooltip.top-end="$t('EDIT_CONTACT.BUTTON_LABEL')"
      icon="i-ph-pencil-simple"
      slate
      faded
      sm
      @click="emit('edit')"
    />
    <ContactMergeModal :primary-contact="contact">
      <template #trigger>
        <NextButton
          v-tooltip.top-end="$t('CONTACT_PANEL.MERGE_CONTACT')"
          icon="i-ph-arrows-merge"
          slate
          faded
          sm
          :disabled="uiFlags.isMerging"
        />
      </template>
    </ContactMergeModal>
    <ContactDeleteModal
      v-if="isAdmin"
      :contact="contact"
      @deleted="emit('deleted')"
    >
      <template #trigger>
        <NextButton
          v-tooltip.top-end="$t('DELETE_CONTACT.BUTTON_LABEL')"
          icon="i-ph-trash"
          slate
          faded
          sm
          ruby
          :disabled="uiFlags.isDeleting"
        />
      </template>
    </ContactDeleteModal>
  </div>
</template>
