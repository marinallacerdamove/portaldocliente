<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import {
  DuplicateContactException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';
import { useAdmin } from 'dashboard/composables/useAdmin';
import ContactInfoRow from './ContactInfoRow.vue';
import Avatar from 'next/avatar/Avatar.vue';
import SocialIcons from './SocialIcons.vue';
import EditContact from './EditContact.vue';
import ContactMergeModal from 'dashboard/modules/contact/ContactMergeModal.vue';
import ContactDeleteModal from 'dashboard/modules/contact/ContactDeleteModal.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import VoiceCallButton from 'dashboard/components-next/Contacts/VoiceCallButton.vue';
import InlineInput from 'dashboard/components-next/inline-input/InlineInput.vue';
import { useCompaniesStore } from 'dashboard/stores/companies';
import CompanyAPI from 'dashboard/api/companies';
import { EMPRESA_ATTRIBUTE_KEY } from 'dashboard/constants/ticketDetailAttributes';
import { useLinkedCompanies } from 'dashboard/composables/useLinkedCompanies';

export default {
  components: {
    NextButton,
    ContactInfoRow,
    EditContact,
    Avatar,
    ComposeConversation,
    SocialIcons,
    ContactMergeModal,
    ContactDeleteModal,
    VoiceCallButton,
    InlineInput,
  },
  props: {
    contact: {
      type: Object,
      default: () => ({}),
    },
    showAvatar: {
      type: Boolean,
      default: true,
    },
  },
  emits: ['panelClose'],
  setup(props) {
    const { isAdmin } = useAdmin();
    const companiesStore = useCompaniesStore();
    const { linkedCompanies } = useLinkedCompanies(
      () => props.contact.company_id,
      () => props.contact.custom_attributes?.empresas_vinculadas
    );
    return {
      isAdmin,
      companiesStore,
      linkedCompanies,
    };
  },
  data() {
    return {
      showEditModal: false,
      // Company do campo Empresa da conversa (achada pelo nome).
      ticketCompanyId: null,
      isEditingName: false,
      editName: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'contacts/getUIFlags',
      currentChat: 'getSelectedChat',
    }),
    // Company nativa do Chatwoot (criada/vinculada automaticamente pelo
    // próprio Chatwoot quando additional_attributes.company_name é
    // preenchido no contato - ver ChatwootService#sync_company no Portal,
    // que depois popula custom_attributes dela com cnpj/site/etc). O
    // payload do contato só traz company_id (ver _contact.json.jbuilder);
    // os dados completos vêm de um fetch separado via companiesStore.
    // PATCH LOCAL (fork) - o card mostra a empresa DO TICKET (campo Empresa
    // em Ações da conversa) e só cai pra empresa do contato quando o ticket
    // não tem empresa. Agente/parceiro sem empresa no Portal abre ticket pra
    // um cliente: sem isso o card ficava sem empresa, ou com a errada.
    ticketCompanyName() {
      return this.currentChat?.custom_attributes?.[EMPRESA_ATTRIBUTE_KEY] || '';
    },
    companyId() {
      return this.ticketCompanyId || this.contact.company_id || null;
    },
    company() {
      return this.companyId
        ? this.companiesStore.getRecord(this.companyId)
        : null;
    },
    companyDocument() {
      return this.company?.customAttributes?.cnpj || '';
    },
    companyLinksHtml() {
      const raw = this.company?.customAttributes?.urls_acesso || '';
      const urls = raw
        .split(',')
        .map(url => url.trim())
        .filter(Boolean);
      if (!urls.length) return '';

      return urls
        .map(url => {
          const href = /^https?:\/\//i.test(url) ? url : `https://${url}`;
          return `<a href="${href}" target="_blank" rel="noopener noreferrer" class="hover:underline">${url}</a>`;
        })
        .join(', ');
    },
    companyProfileLink() {
      return this.companyLink(this.companyId);
    },
    otherCompanies() {
      return this.linkedCompanies.filter(c => c.id !== this.company?.id);
    },
    additionalAttributes() {
      return this.contact.additional_attributes || {};
    },
    classificacaoCliente() {
      return (this.contact.custom_attributes || {}).classificacao_cliente || '';
    },
    classificacaoTagHtml() {
      if (!this.classificacaoCliente) return '';
      const colors = {
        A: 'bg-emerald-500',
        B: 'bg-amber-500',
        C: 'bg-gray-400',
      };
      const colorClass = colors[this.classificacaoCliente] || 'bg-gray-400';
      return `<span class="inline-flex items-center justify-center px-2 py-0.5 rounded text-white text-xs font-bold ${colorClass}">${this.classificacaoCliente}</span>`;
    },
    socialProfiles() {
      const {
        social_profiles: socialProfiles,
        screen_name: twitterScreenName,
        social_telegram_user_name: telegramUsername,
      } = this.additionalAttributes;

      const telegram = socialProfiles?.telegram || telegramUsername || '';
      const twitter = socialProfiles?.twitter || twitterScreenName || '';

      return {
        ...(socialProfiles || {}),
        twitter,
        telegram,
      };
    },
  },
  watch: {
    'contact.id': {
      handler(id) {
        this.$store.dispatch('contacts/fetchContactableInbox', id);
      },
      immediate: true,
    },
    ticketCompanyName: {
      handler(name) {
        this.resolveTicketCompany(name);
      },
      immediate: true,
    },
    companyId: {
      handler(id) {
        if (id) this.companiesStore.show(id);
      },
      immediate: true,
    },
  },
  methods: {
    async resolveTicketCompany(name) {
      this.ticketCompanyId = null;
      if (!name) return;
      try {
        const {
          data: { payload },
        } = await CompanyAPI.search(name);
        if (name !== this.ticketCompanyName) return;
        const target = name.trim().toLowerCase();
        const match = (payload || []).find(
          item => item.name?.trim().toLowerCase() === target
        );
        this.ticketCompanyId = match?.id || null;
      } catch {
        this.ticketCompanyId = null;
      }
    },
    companyLink(companyId) {
      return `/app/accounts/${this.$route.params.accountId}/companies/${companyId}`;
    },
    toggleEditModal() {
      this.showEditModal = !this.showEditModal;
    },
    startEditingName() {
      this.editName = this.contact.name || '';
      this.isEditingName = true;
      this.$nextTick(() => {
        this.$refs.nameInput?.focus();
      });
    },
    saveNameEdit() {
      if (!this.isEditingName) return;
      this.isEditingName = false;
      const trimmed = this.editName.trim();
      if (trimmed && trimmed !== this.contact.name) {
        this.updateContactField({ name: trimmed });
      }
    },
    cancelNameEdit() {
      this.isEditingName = false;
    },
    onFieldUpdate(field, value) {
      this.updateContactField({ [field]: value });
    },
    async updateContactField(attrs) {
      const contactId = this.contact.id;
      try {
        await this.$store.dispatch('contacts/update', {
          id: contactId,
          ...attrs,
        });
        useAlert(this.$t('CONTACT_FORM.SUCCESS_MESSAGE'));
        await this.$store.dispatch('contacts/fetchContactableInbox', contactId);
      } catch (error) {
        if (error instanceof DuplicateContactException) {
          const detail = error.contactErrorDetail;
          if (detail) {
            useAlert(detail);
          } else {
            const invalidAttrs = Array.isArray(error.data) ? error.data : [];
            if (invalidAttrs.includes('email')) {
              useAlert(this.$t('CONTACT_FORM.FORM.EMAIL_ADDRESS.DUPLICATE'));
            } else if (invalidAttrs.includes('phone_number')) {
              useAlert(this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.DUPLICATE'));
            } else {
              useAlert(this.$t('CONTACT_FORM.ERROR_MESSAGE'));
            }
          }
        } else if (error instanceof ExceptionWithMessage) {
          useAlert(error.data);
        } else {
          useAlert(error.message || this.$t('CONTACT_FORM.ERROR_MESSAGE'));
        }
      }
    },
  },
};
</script>

<template>
  <div class="relative items-center w-full p-4">
    <div
      class="flex flex-col w-full gap-3 p-3 border rounded-lg shadow-sm border-n-weak bg-n-solid-1"
    >
      <div
        v-if="company?.id"
        class="flex flex-col gap-2 pb-2 border-b border-n-weak"
      >
        <div class="flex items-center gap-2">
          <Avatar :name="company.name" :size="28" hide-offline-status />
          <div class="flex flex-col min-w-0">
            <h3
              class="max-w-full my-0 text-sm font-medium truncate text-n-slate-12"
            >
              {{ company.name }}
            </h3>
            <span class="text-xs text-n-slate-10">
              {{ $t('CONTACT_PANEL.COMPANY_LABEL') }}
            </span>
          </div>
        </div>
        <div class="flex flex-col items-start w-full gap-2">
          <ContactInfoRow
            v-if="companyDocument"
            :value="companyDocument"
            icon="contact-identify"
            emoji="🪪"
            :title="$t('CONTACT_PANEL.COMPANY_DOCUMENT')"
            show-copy
          />
          <ContactInfoRow
            v-if="companyLinksHtml"
            :value="companyLinksHtml"
            icon="link"
            emoji="🔗"
            :title="$t('CONTACT_PANEL.COMPANY_WEBSITE')"
          />
        </div>
        <div v-if="otherCompanies.length" class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-10">
            {{ $t('CONTACT_PANEL.OTHER_COMPANIES') }}
          </span>
          <div class="flex flex-wrap gap-1.5">
            <router-link
              v-for="other in otherCompanies"
              :key="other.id"
              :to="companyLink(other.id)"
              class="px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-blue-11 hover:underline"
            >
              {{ other.name }}
            </router-link>
          </div>
        </div>
        <NextButton
          :label="$t('CONTACT_PANEL.VIEW_COMPANY')"
          faded
          slate
          xs
          class="self-start"
          @click="$router.push(companyProfileLink)"
        />
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
            :conversation-id="currentChat?.id"
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
            @click="toggleEditModal"
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
            @deleted="$emit('panelClose')"
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
      </div>
      <div
        v-else
        class="flex flex-col items-center gap-2 pb-3 text-center border-b border-n-weak"
      >
        <Avatar
          v-if="showAvatar"
          :src="contact.thumbnail"
          :name="contact.name"
          :status="contact.availability_status"
          :size="56"
          hide-offline-status
        />
        <div class="flex items-center gap-2 group/name">
          <InlineInput
            v-if="isEditingName"
            ref="nameInput"
            v-model="editName"
            custom-input-class="!text-base !font-medium !w-auto max-w-full [field-sizing:content]"
            class="!w-fit min-w-0"
            @enter-press="saveNameEdit"
            @escape-press="cancelNameEdit"
            @blur="saveNameEdit"
          />
          <h3
            v-else
            class="flex-shrink max-w-full min-w-0 my-0 text-base capitalize break-words text-n-slate-12 cursor-pointer hover:text-n-slate-12/80"
            :title="$t('CONTACT_PANEL.CLICK_TO_EDIT')"
            @click="startEditingName"
          >
            {{ contact.name }}
          </h3>
          <NextButton
            ghost
            xs
            slate
            icon="i-lucide-pencil"
            :title="$t('CONTACT_PANEL.CLICK_TO_EDIT')"
            class="flex-shrink-0 -mx-1 opacity-0 transition-opacity"
            :class="
              isEditingName
                ? 'invisible'
                : 'group-hover/name:opacity-100 focus-visible:opacity-100'
            "
            @click="startEditingName"
          />
        </div>
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
            :conversation-id="currentChat?.id"
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
            @click="toggleEditModal"
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
            @deleted="$emit('panelClose')"
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
      </div>

      <div>
        <span
          v-if="company?.id"
          class="text-xs font-semibold tracking-wide uppercase text-n-slate-10"
        >
          {{ $t('CONTACT_PANEL.REQUESTER_LABEL') }}
        </span>
        <div
          class="flex flex-col items-start w-full gap-2"
          :class="{ 'mt-2': company?.id }"
        >
          <ContactInfoRow
            v-if="company?.id"
            :value="contact.name"
            icon="person"
            emoji="👤"
            :title="$t('CONTACT_PANEL.REQUESTER_NAME')"
            editable
            @update="value => updateContactField({ name: value })"
          />
          <ContactInfoRow
            :href="contact.email ? `mailto:${contact.email}` : ''"
            :value="contact.email"
            icon="mail"
            emoji="✉️"
            :title="$t('CONTACT_PANEL.EMAIL_ADDRESS')"
            show-copy
            editable
            @update="value => onFieldUpdate('email', value)"
          />
          <ContactInfoRow
            :href="contact.phone_number ? `tel:${contact.phone_number}` : ''"
            :value="contact.phone_number"
            icon="call"
            emoji="📞"
            :title="$t('CONTACT_PANEL.PHONE_NUMBER')"
            show-copy
            editable
            @update="value => onFieldUpdate('phone_number', value)"
          />
          <ContactInfoRow
            v-if="contact.identifier"
            :value="contact.identifier"
            icon="contact-identify"
            emoji="🪪"
            :title="$t('CONTACT_PANEL.IDENTIFIER')"
          />
          <ContactInfoRow
            v-if="!company?.id && additionalAttributes.company_name"
            :value="additionalAttributes.company_name"
            icon="building-bank"
            emoji="🏢"
            :title="$t('CONTACT_PANEL.COMPANY')"
            editable
            @update="
              value =>
                updateContactField({
                  additional_attributes: {
                    ...additionalAttributes,
                    company_name: value,
                  },
                })
            "
          />
          <ContactInfoRow
            v-if="classificacaoCliente"
            :value="classificacaoTagHtml"
            icon="tag"
            emoji="🏷️"
            :title="$t('CONTACT_PANEL.CLASSIFICATION')"
          />
        </div>
      </div>

      <SocialIcons :social-profiles="socialProfiles" />
    </div>
    <EditContact
      :show="showEditModal"
      :contact="contact"
      @cancel="toggleEditModal"
    />
  </div>
</template>
