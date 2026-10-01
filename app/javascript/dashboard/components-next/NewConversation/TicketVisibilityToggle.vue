<script setup>
import { useI18n } from 'vue-i18n';

// PATCH LOCAL (fork) - Interno (padrão: o cliente não vê nem é notificado)
// x Visível ao cliente. Usado no Novo ticket interno e no ticket pai/filho.
const visibleToClient = defineModel({ type: Boolean, default: false });

const { t } = useI18n();

const VISIBILITY_OPTIONS = [
  {
    key: 'internal',
    visible: false,
    icon: 'i-lucide-lock',
    label: 'NEW_INTERNAL_TICKET_DIALOG.INTERNAL_TICKET_BADGE',
    activeClass: 'text-n-amber-11',
  },
  {
    key: 'visible',
    visible: true,
    icon: 'i-lucide-eye',
    label: 'NEW_INTERNAL_TICKET_DIALOG.VISIBLE_TO_CLIENT_BADGE',
    activeClass: 'text-n-teal-11',
  },
];
</script>

<template>
  <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
    <div class="inline-flex gap-0.5 p-0.5 rounded-lg bg-n-alpha-2">
      <button
        v-for="option in VISIBILITY_OPTIONS"
        :key="option.key"
        type="button"
        class="flex items-center gap-1.5 h-7 px-3 text-xs font-medium transition-colors rounded-md"
        :class="
          visibleToClient === option.visible
            ? `bg-n-solid-1 shadow-sm ${option.activeClass}`
            : 'text-n-slate-11 hover:text-n-slate-12'
        "
        @click="visibleToClient = option.visible"
      >
        <span :class="option.icon" class="size-3.5" />
        {{ t(option.label) }}
      </button>
    </div>
    <p class="mb-0 text-xs text-n-slate-10">
      {{
        visibleToClient
          ? t('NEW_INTERNAL_TICKET_DIALOG.VISIBLE_TO_CLIENT_HELP')
          : t('NEW_INTERNAL_TICKET_DIALOG.INTERNAL_TICKET_HELP')
      }}
    </p>
  </div>
</template>
