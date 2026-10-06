<script setup>
// PATCH LOCAL (fork) - "Cadastrar contato" abaixo do Solicitante, só para
// contato que ainda não é usuário do Portal. Cadastra no Portal (usuário
// Cliente sem acesso, na empresa do contato; a conversa vira ticket) e/ou
// completa o contato no Chatwoot (só preenche, nunca apaga).
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ConversationApi from 'dashboard/api/inbox/conversation';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  contact: { type: Object, required: true },
  conversationId: { type: Number, required: true },
  companyName: { type: String, default: '' },
});

const PORTAL_PARTNER_IDENTIFIER = /^portal_partner_\d+$/;

const { t } = useI18n();
const store = useStore();
const dialogRef = ref(null);
const isSaving = ref(false);
const form = reactive({
  name: '',
  email: '',
  phone: '',
  registerPortal: true,
  completeChatwoot: true,
});

const isPortalUser = computed(
  () =>
    Boolean(props.contact.custom_attributes?.portal_usuario_id) ||
    PORTAL_PARTNER_IDENTIFIER.test(props.contact.identifier || '')
);
const missingCompany = computed(
  () => form.registerPortal && !props.contact.company_id
);
const canSubmit = computed(
  () =>
    (form.registerPortal || form.completeChatwoot) &&
    !missingCompany.value &&
    (!form.registerPortal || form.email.trim())
);

const open = () => {
  form.name = props.contact.name || '';
  form.email = props.contact.email || '';
  form.phone = props.contact.phone_number || '';
  form.registerPortal = true;
  form.completeChatwoot = true;
  dialogRef.value.open();
};

const successMessage = data => {
  if (!form.registerPortal) {
    return t('PORTAL_CONTACT_REGISTRATION.SUCCESS_CHATWOOT');
  }
  const registered = data.created
    ? t('PORTAL_CONTACT_REGISTRATION.SUCCESS_CREATED')
    : t('PORTAL_CONTACT_REGISTRATION.SUCCESS_LINKED');
  return data.ticket_requested
    ? `${registered} ${t('PORTAL_CONTACT_REGISTRATION.SUCCESS_TICKET')}`
    : registered;
};

const submit = async () => {
  isSaving.value = true;
  try {
    const { data } = await ConversationApi.registerPortalContact(
      props.conversationId,
      {
        name: form.name.trim(),
        email: form.email.trim(),
        phone: form.phone.trim(),
        register_portal: form.registerPortal,
        complete_chatwoot: form.completeChatwoot,
      }
    );
    await store.dispatch('contacts/show', { id: props.contact.id });
    useAlert(successMessage(data));
    dialogRef.value.close();
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('PORTAL_CONTACT_REGISTRATION.ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div class="w-full">
    <div v-if="!isPortalUser" class="flex flex-col items-start gap-1 w-full">
      <span class="text-xs text-n-slate-11">
        {{ $t('PORTAL_CONTACT_REGISTRATION.NOT_REGISTERED') }}
      </span>
      <NextButton
        xs
        slate
        faded
        icon="i-lucide-user-plus"
        :label="$t('PORTAL_CONTACT_REGISTRATION.BUTTON')"
        @click="open"
      />
      <Dialog
        ref="dialogRef"
        :title="$t('PORTAL_CONTACT_REGISTRATION.TITLE')"
        :description="$t('PORTAL_CONTACT_REGISTRATION.DESCRIPTION')"
        :confirm-button-label="$t('PORTAL_CONTACT_REGISTRATION.CONFIRM')"
        :disable-confirm-button="!canSubmit"
        :is-loading="isSaving"
        @confirm="submit"
      >
        <div class="flex flex-col gap-3">
          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <Checkbox v-model="form.registerPortal" />
            {{ $t('PORTAL_CONTACT_REGISTRATION.REGISTER_PORTAL') }}
          </label>
          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <Checkbox v-model="form.completeChatwoot" />
            {{ $t('PORTAL_CONTACT_REGISTRATION.COMPLETE_CHATWOOT') }}
          </label>
          <Input
            v-model="form.name"
            :label="$t('PORTAL_CONTACT_REGISTRATION.NAME')"
          />
          <Input
            v-model="form.email"
            type="email"
            :label="$t('PORTAL_CONTACT_REGISTRATION.EMAIL')"
          />
          <Input
            v-model="form.phone"
            :label="$t('PORTAL_CONTACT_REGISTRATION.PHONE')"
          />
          <p v-if="form.registerPortal" class="text-xs text-n-slate-11 mb-0">
            {{
              companyName
                ? $t('PORTAL_CONTACT_REGISTRATION.COMPANY_HINT', {
                    company: companyName,
                  })
                : $t('PORTAL_CONTACT_REGISTRATION.NO_COMPANY')
            }}
          </p>
        </div>
      </Dialog>
    </div>
  </div>
</template>
