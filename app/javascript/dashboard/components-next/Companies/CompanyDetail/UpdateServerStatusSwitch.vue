<script setup>
// PATCH LOCAL (fork) - liga/desliga "ativo" direto na linha (sem exclusão: a
// base ou licença só sai de uso). Mostra o estado em texto ao lado do switch.
import { useI18n } from 'vue-i18n';
import Switch from 'dashboard/components-next/switch/Switch.vue';

defineProps({
  active: { type: Boolean, default: false },
  busy: { type: Boolean, default: false },
  label: { type: String, default: '' },
});
const emit = defineEmits(['toggle']);

const { t } = useI18n();
</script>

<template>
  <div class="inline-flex items-center gap-2" @click.stop>
    <Switch
      :model-value="active"
      :disabled="busy"
      :aria-label="label"
      :class="{ 'opacity-50 pointer-events-none': busy }"
      @update:model-value="emit('toggle', $event)"
    />
    <span
      class="text-xs"
      :class="active ? 'text-n-teal-11' : 'text-n-slate-10'"
      aria-live="polite"
    >
      {{
        active
          ? t('COMPANIES.DETAIL.UPDATE_SERVER.ACTIVE_BADGE')
          : t('COMPANIES.DETAIL.UPDATE_SERVER.INACTIVE_BADGE')
      }}
    </span>
  </div>
</template>
