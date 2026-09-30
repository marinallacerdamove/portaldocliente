<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import CompanyAPI from 'dashboard/api/companies';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

defineProps({
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['create']);

const { t } = useI18n();
const dialogRef = ref(null);

const form = reactive({ name: '', cnpj: '', domain: '', description: '' });

// PATCH LOCAL (fork) - empresa daqui é espelhada no Portal do Cliente, que
// exige CPF/CNPJ e usa ele como chave de vínculo. Mesmas regras do Portal
// (Empresa#normalize_cnpj/cnpj_format): CPF 11 dígitos, CNPJ 14 caracteres
// (12 alfanuméricos + 2 dígitos verificadores, reforma tributária).
const cnpjKey = value =>
  (value || '').replace(/[^0-9A-Za-z]/g, '').toUpperCase();
const normalizeName = value =>
  (value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase();

const isCnpjValid = computed(() => {
  const key = cnpjKey(form.cnpj);
  if (key.length === 11) return /^\d{11}$/.test(key);
  if (key.length === 14) return /^[0-9A-Z]{12}\d{2}$/.test(key);
  return false;
});

const formatCnpj = value => {
  const key = cnpjKey(value);
  if (key.length === 14)
    return `${key.slice(0, 2)}.${key.slice(2, 5)}.${key.slice(5, 8)}/${key.slice(8, 12)}-${key.slice(12)}`;
  if (key.length === 11)
    return `${key.slice(0, 3)}.${key.slice(3, 6)}.${key.slice(6, 9)}-${key.slice(9)}`;
  return key;
};

const cnpjError = ref('');
const nameWarning = ref('');
const isChecking = ref(false);

watch(
  () => [form.name, form.cnpj],
  () => {
    cnpjError.value = '';
    nameWarning.value = '';
  }
);

const isFormInvalid = computed(() => !form.name.trim() || !isCnpjValid.value);

const cnpjMessage = computed(() => {
  if (cnpjError.value) return cnpjError.value;
  if (form.cnpj && !isCnpjValid.value)
    return t('COMPANIES.CREATE.CNPJ_INVALID');
  return '';
});

const resetForm = () => {
  form.name = '';
  form.cnpj = '';
  form.domain = '';
  form.description = '';
};

const open = (company = {}) => {
  form.name = company.name || '';
  form.cnpj = company.cnpj || '';
  form.domain = company.domain || '';
  form.description = company.description || '';
  dialogRef.value?.open();
};

const searchCompanies = async query => {
  const {
    data: { payload },
  } = await CompanyAPI.search(query);
  return payload || [];
};

// Só aqui dentro da conta - uma empresa que existe no Portal mas não nesta
// conta é ligada pelo CPF/CNPJ quando chega lá (sem duplicar), e cada
// revenda não enxerga as empresas das outras.
const findDuplicates = async () => {
  const [byCnpj, byName] = await Promise.all([
    searchCompanies(cnpjKey(form.cnpj)),
    searchCompanies(form.name.trim()),
  ]);
  const key = cnpjKey(form.cnpj);
  const sameCnpj = byCnpj.find(c => cnpjKey(c.custom_attributes?.cnpj) === key);
  const sameName = byName.find(
    c => normalizeName(c.name) === normalizeName(form.name)
  );
  return { sameCnpj, sameName };
};

const handleConfirm = async () => {
  if (isFormInvalid.value) return;

  // Segundo clique depois do aviso de nome igual = confirmação explícita.
  if (!nameWarning.value) {
    isChecking.value = true;
    try {
      const { sameCnpj, sameName } = await findDuplicates();
      if (sameCnpj) {
        cnpjError.value = t('COMPANIES.CREATE.DUPLICATE_CNPJ', {
          name: sameCnpj.name,
        });
        return;
      }
      if (sameName) {
        nameWarning.value = t('COMPANIES.CREATE.DUPLICATE_NAME', {
          name: sameName.name,
          cnpj: sameName.custom_attributes?.cnpj || '-',
        });
        return;
      }
    } finally {
      isChecking.value = false;
    }
  }

  emit('create', {
    name: form.name.trim(),
    domain: form.domain.trim() || null,
    description: form.description.trim() || null,
    custom_attributes: { cnpj: formatCnpj(form.cnpj) },
  });
};

const closeDialog = () => {
  dialogRef.value?.close();
};

const onSuccess = () => {
  resetForm();
  closeDialog();
};

defineExpose({ dialogRef, onSuccess, open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="3xl"
    overflow-y-auto
    @confirm="handleConfirm"
    @close="resetForm"
  >
    <div class="flex flex-col gap-6">
      <div class="flex flex-col items-start gap-2">
        <span class="py-1 text-sm font-medium text-n-slate-12">
          {{ t('COMPANIES.CREATE.TITLE') }}
        </span>
        <div class="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
          <Input
            v-model="form.name"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.NAME')"
            :disabled="isLoading"
            custom-input-class="h-8 !pt-1 !pb-1 [&:not(.error,.focus)]:!outline-transparent"
            autofocus
          />
          <Input
            v-model="form.cnpj"
            :placeholder="t('COMPANIES.CREATE.CNPJ_PLACEHOLDER')"
            :disabled="isLoading"
            :message="cnpjMessage"
            :message-type="cnpjMessage ? 'error' : 'info'"
            custom-input-class="h-8 !pt-1 !pb-1 [&:not(.error,.focus)]:!outline-transparent"
          />
          <Input
            v-model="form.domain"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.DOMAIN')"
            :disabled="isLoading"
            custom-input-class="h-8 !pt-1 !pb-1 [&:not(.error,.focus)]:!outline-transparent"
          />
        </div>
      </div>
      <TextArea
        v-model="form.description"
        :placeholder="t('COMPANIES.DETAIL.PROFILE.DESCRIPTION_PLACEHOLDER')"
        :disabled="isLoading"
        :max-length="280"
        class="w-full"
        show-character-count
        auto-height
      />
      <p
        v-if="nameWarning"
        class="px-3 py-2 mb-0 text-sm rounded-lg bg-n-amber-3 text-n-amber-12"
      >
        {{ nameWarning }}
      </p>
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <Button
          :label="t('DIALOG.BUTTONS.CANCEL')"
          variant="link"
          type="reset"
          class="h-10 hover:!no-underline hover:text-n-brand"
          @click="closeDialog"
        />
        <Button
          :label="
            nameWarning
              ? t('COMPANIES.CREATE.ACTIONS.SAVE_ANYWAY')
              : t('COMPANIES.CREATE.ACTIONS.SAVE')
          "
          color="blue"
          type="submit"
          :disabled="isFormInvalid || isLoading || isChecking"
          :is-loading="isLoading || isChecking"
        />
      </div>
    </template>
  </Dialog>
</template>
