<script setup>
import { computed, ref, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useLinkedCompanies } from 'dashboard/composables/useLinkedCompanies';
import { dynamicTime } from 'shared/helpers/timeHelper';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ContactLabels from 'dashboard/components-next/Contacts/ContactLabels/ContactLabels.vue';
import ContactsForm from 'dashboard/components-next/Contacts/ContactsForm/ContactsForm.vue';
import ConfirmContactDeleteDialog from 'dashboard/components-next/Contacts/ContactsForm/ConfirmContactDeleteDialog.vue';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import InfoCardFields from 'dashboard/components-next/InfoCard/InfoCardFields.vue';
import Policy from 'dashboard/components/policy.vue';

const props = defineProps({
  selectedContact: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['goToContactsList']);

const { t } = useI18n();
const store = useStore();
const route = useRoute();

// Nomes de marca - não traduzidos.
const SOCIAL_NETWORKS = {
  linkedin: 'LinkedIn',
  facebook: 'Facebook',
  instagram: 'Instagram',
  telegram: 'Telegram',
  tiktok: 'TikTok',
  twitter: 'X (Twitter)',
  github: 'GitHub',
};

const confirmDeleteContactDialogRef = ref(null);

const avatarFile = ref(null);
const avatarUrl = ref('');

const contactsFormRef = ref(null);

const uiFlags = useMapGetter('contacts/getUIFlags');
const isUpdating = computed(() => uiFlags.value.isUpdating);

const isFormInvalid = computed(() => contactsFormRef.value?.isFormInvalid);

const contactData = ref({});
// PATCH LOCAL (fork) - ficha em cards (padrão do Portal): um card em edição
// por vez, com Cancelar/Salvar próprios.
const editingSection = ref(null);

const getInitialContactData = () => {
  if (!props.selectedContact) return {};
  return { ...props.selectedContact };
};

const resetContactData = () => {
  contactData.value = getInitialContactData();
};

onMounted(resetContactData);

// Não sobrescreve o que está sendo digitado se o contato for atualizado por
// fora (ex.: sincronização vinda do Portal) no meio da edição.
watch(
  () => props.selectedContact,
  () => {
    if (!editingSection.value) resetContactData();
  },
  { deep: true }
);

const createdAt = computed(() => {
  return contactData.value?.createdAt
    ? dynamicTime(contactData.value.createdAt)
    : '';
});

const lastActivityAt = computed(() => {
  return contactData.value?.lastActivityAt
    ? dynamicTime(contactData.value.lastActivityAt)
    : '';
});

const avatarSrc = computed(() => {
  return avatarUrl.value ? avatarUrl.value : contactData.value?.thumbnail;
});

const additionalAttributes = computed(
  () => props.selectedContact?.additionalAttributes || {}
);

const { linkedCompanies } = useLinkedCompanies(
  () => props.selectedContact?.companyId,
  () => props.selectedContact?.customAttributes?.empresas_vinculadas
);

const companyLinks = computed(() =>
  linkedCompanies.value.map(company => ({
    id: company.id,
    label: company.name,
    to: {
      name: 'companies_dashboard_show',
      params: { accountId: route.params.accountId, companyId: company.id },
    },
  }))
);

const headerSubtitle = computed(() =>
  [additionalAttributes.value.companyName, props.selectedContact?.email]
    .filter(Boolean)
    .join(' · ')
);

const detailsItems = computed(() => [
  {
    key: 'name',
    label: t('CONTACTS_LAYOUT.DETAILS.INFO_CARD.NAME'),
    value: props.selectedContact?.name || '',
  },
  {
    key: 'email',
    label: t('CONTACTS_LAYOUT.DETAILS.INFO_CARD.EMAIL'),
    value: props.selectedContact?.email || '',
  },
  {
    key: 'phone',
    label: t('CONTACTS_LAYOUT.DETAILS.INFO_CARD.PHONE'),
    value: props.selectedContact?.phoneNumber || '',
  },
  // Contato sem Company no Chatwoot (só o nome digitado) cai no texto.
  companyLinks.value.length
    ? {
        key: 'companies',
        label: t('CONTACTS_LAYOUT.DETAILS.INFO_CARD.LINKED_COMPANIES'),
        value: companyLinks.value,
        kind: 'links',
      }
    : {
        key: 'company',
        label: t('CONTACTS_LAYOUT.DETAILS.INFO_CARD.COMPANY'),
        value: additionalAttributes.value.companyName || '',
      },
  {
    key: 'bio',
    label: t('CONTACTS_LAYOUT.DETAILS.INFO_CARD.BIO'),
    value: additionalAttributes.value.description || '',
    kind: 'multiline',
    full: true,
  },
]);

const socialItems = computed(() => {
  const profiles = additionalAttributes.value.socialProfiles || {};
  const filled = Object.entries(SOCIAL_NETWORKS)
    .filter(([key]) => profiles[key])
    .map(([key, label]) => ({ key, label, value: profiles[key] }));
  return filled.length
    ? filled
    : [
        {
          key: 'none',
          label: t('CONTACTS_LAYOUT.DETAILS.INFO_CARD.NO_SOCIAL'),
          value: '',
          full: true,
        },
      ];
});

const cardProps = section => ({
  isEditing: editingSection.value === section,
  canEdit: !editingSection.value,
  isSaving: isUpdating.value,
  saveDisabled: !!isFormInvalid.value,
});

const handleFormUpdate = updatedData => {
  Object.assign(contactData.value, updatedData);
};

const updateContact = async () => {
  try {
    const { customAttributes, ...basicContactData } = contactData.value;
    await store.dispatch('contacts/update', basicContactData);
    await store.dispatch(
      'contacts/fetchContactableInbox',
      props.selectedContact.id
    );
    useAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SUCCESS_MESSAGE'));
    return true;
  } catch (error) {
    useAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ERROR_MESSAGE'));
    return false;
  }
};

const startEdit = section => {
  resetContactData();
  editingSection.value = section;
};

const cancelEdit = () => {
  editingSection.value = null;
  resetContactData();
};

const saveSection = async () => {
  if (await updateContact()) {
    editingSection.value = null;
    resetContactData();
  }
};

const openConfirmDeleteContactDialog = () => {
  confirmDeleteContactDialogRef.value?.dialogRef.open();
};

const handleAvatarUpload = async ({ file, url }) => {
  avatarFile.value = file;
  avatarUrl.value = url;

  try {
    await store.dispatch('contacts/update', {
      id: props.selectedContact.id,
      avatar: file,
      isFormData: true,
    });
    useAlert(t('CONTACTS_LAYOUT.DETAILS.AVATAR.UPLOAD.SUCCESS_MESSAGE'));
  } catch {
    useAlert(t('CONTACTS_LAYOUT.DETAILS.AVATAR.UPLOAD.ERROR_MESSAGE'));
  }
};

const handleAvatarDelete = async () => {
  try {
    if (props.selectedContact && props.selectedContact.id) {
      await store.dispatch('contacts/deleteAvatar', props.selectedContact.id);
      useAlert(t('CONTACTS_LAYOUT.DETAILS.AVATAR.DELETE.SUCCESS_MESSAGE'));
    }
    avatarFile.value = null;
    avatarUrl.value = '';
    contactData.value.thumbnail = null;
  } catch (error) {
    useAlert(
      error.message
        ? error.message
        : t('CONTACTS_LAYOUT.DETAILS.AVATAR.DELETE.ERROR_MESSAGE')
    );
  }
};
</script>

<template>
  <div class="flex flex-col w-full gap-5 pb-6">
    <div class="flex flex-col items-start gap-3">
      <div class="flex items-center gap-4">
        <Avatar
          :src="avatarSrc || ''"
          :name="selectedContact?.name || ''"
          :size="56"
          allow-upload
          @upload="handleAvatarUpload"
          @delete="handleAvatarDelete"
        />
        <div class="flex flex-col min-w-0 gap-0.5">
          <h3 class="my-0 text-lg font-semibold truncate text-n-slate-12">
            {{ selectedContact?.name }}
          </h3>
          <span v-if="headerSubtitle" class="text-sm text-n-slate-11">
            {{ headerSubtitle }}
          </span>
          <span class="inline-flex items-center gap-1 text-xs text-n-slate-10">
            <template v-if="selectedContact?.identifier">
              <span class="i-ph-user-gear size-3.5" />
              {{ selectedContact.identifier }}
              •
            </template>
            {{ $t('CONTACTS_LAYOUT.DETAILS.CREATED_AT', { date: createdAt }) }}
            •
            {{
              $t('CONTACTS_LAYOUT.DETAILS.LAST_ACTIVITY', {
                date: lastActivityAt,
              })
            }}
          </span>
        </div>
      </div>
      <ContactLabels :contact-id="selectedContact?.id" />
    </div>

    <InfoCard
      :title="t('CONTACTS_LAYOUT.DETAILS.INFO_CARD.DETAILS_TITLE')"
      icon="i-lucide-user-round"
      v-bind="cardProps('details')"
      @edit="startEdit('details')"
      @cancel="cancelEdit"
      @save="saveSection"
    >
      <InfoCardFields :items="detailsItems" />
      <template #edit>
        <ContactsForm
          ref="contactsFormRef"
          :contact-data="contactData"
          section="details"
          is-details-view
          @update="handleFormUpdate"
        />
      </template>
    </InfoCard>

    <InfoCard
      :title="t('CONTACTS_LAYOUT.DETAILS.INFO_CARD.SOCIAL_TITLE')"
      icon="i-lucide-share-2"
      v-bind="cardProps('social')"
      @edit="startEdit('social')"
      @cancel="cancelEdit"
      @save="saveSection"
    >
      <InfoCardFields :items="socialItems" />
      <template #edit>
        <ContactsForm
          ref="contactsFormRef"
          :contact-data="contactData"
          section="social"
          is-details-view
          @update="handleFormUpdate"
        />
      </template>
    </InfoCard>

    <Policy :permissions="['administrator']">
      <div
        class="flex flex-col items-start w-full gap-4 pt-6 border-t border-n-strong"
      >
        <div class="flex flex-col gap-2">
          <h6 class="text-base font-medium text-n-slate-12">
            {{ t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT') }}
          </h6>
          <span class="text-sm text-n-slate-11">
            {{ t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT_DESCRIPTION') }}
          </span>
        </div>
        <Button
          :label="t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT')"
          color="ruby"
          @click="openConfirmDeleteContactDialog"
        />
      </div>
      <ConfirmContactDeleteDialog
        ref="confirmDeleteContactDialogRef"
        :selected-contact="selectedContact"
        @go-to-contacts-list="emit('goToContactsList')"
      />
    </Policy>
  </div>
</template>
