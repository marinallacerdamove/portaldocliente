<script setup>
// PATCH LOCAL (fork) - selo Ativa/Inativa das empresas e contatos de um grupo.
import { useI18n } from 'vue-i18n';

defineProps({
  active: { type: Boolean, default: false },
});

const { t } = useI18n();
</script>

<template>
  <span
    class="inline-flex px-2 py-0.5 text-xs font-medium rounded-md"
    :class="
      active ? 'bg-n-teal-3 text-n-teal-11' : 'bg-n-slate-3 text-n-slate-11'
    "
  >
    {{
      active
        ? t('PORTAL_GROUPS.STATUS.ACTIVE')
        : t('PORTAL_GROUPS.STATUS.INACTIVE')
    }}
  </span>
</template>
