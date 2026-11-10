<script setup>
// PATCH LOCAL (fork) - situação de um contato de empresa dentro de um grupo,
// como o Portal calcula: recebe, inativo, sem telefone ou sem cadastro nesta
// conta do Chatwoot.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  status: { type: String, default: 'recebe' },
});

const { t } = useI18n();

// Classes literais pro Tailwind enxergar.
const COLOR_CLASSES = {
  recebe: 'bg-n-teal-3 text-n-teal-11',
  inativos: 'bg-n-slate-3 text-n-slate-11',
  sem_telefone: 'bg-n-amber-3 text-n-amber-11',
  sem_contato_no_chatwoot: 'bg-n-amber-3 text-n-amber-11',
};

const label = computed(
  () =>
    ({
      recebe: t('PORTAL_GROUPS.CONTACT_STATUS.RECEIVES'),
      inativos: t('PORTAL_GROUPS.CONTACT_STATUS.INACTIVE'),
      sem_telefone: t('PORTAL_GROUPS.CONTACT_STATUS.NO_PHONE'),
      sem_contato_no_chatwoot: t('PORTAL_GROUPS.CONTACT_STATUS.NO_CHATWOOT'),
    })[props.status] || t('PORTAL_GROUPS.CONTACT_STATUS.INACTIVE')
);
</script>

<template>
  <span
    class="inline-flex px-2 py-0.5 text-xs font-medium rounded-md whitespace-nowrap"
    :class="COLOR_CLASSES[status] || COLOR_CLASSES.inativos"
  >
    {{ label }}
  </span>
</template>
