<script setup>
// PATCH LOCAL (fork) - botão "Variáveis": lista todas as nossas variáveis
// agrupadas (ticket, cliente, atendente, outras) e devolve "{{chave}}" pra
// quem chamou inserir no texto.
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import { PORTAL_VARIABLE_GROUPS } from 'shared/constants/portalVariables';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['insert']);

const { t } = useI18n();
const isOpen = ref(false);
const toggleRef = ref(null);

const close = () => {
  isOpen.value = false;
};

const token = key => `{{${key}}}`;

const select = key => {
  emit('insert', token(key));
  close();
};
</script>

<template>
  <div class="relative">
    <Button
      ref="toggleRef"
      :label="t('MACROS.VARIABLES.TITLE')"
      icon="i-lucide-braces"
      xs
      faded
      slate
      @click="isOpen = !isOpen"
    />
    <div
      v-if="isOpen"
      v-on-click-outside="[close, { ignore: [toggleRef] }]"
      class="absolute z-50 flex flex-col w-80 max-w-[calc(100vw-2rem)] max-h-80 mt-1 overflow-y-auto border shadow-lg ltr:right-0 rtl:left-0 top-full rounded-xl border-n-weak bg-n-solid-1"
    >
      <p class="px-3 pt-2 pb-1 mb-0 text-xs text-n-slate-10">
        {{ t('MACROS.VARIABLES.HINT') }}
      </p>
      <div
        v-for="group in PORTAL_VARIABLE_GROUPS"
        :key="group.key"
        class="py-1"
      >
        <p
          class="px-3 pt-1 pb-0.5 mb-0 text-xs font-medium tracking-wide uppercase text-n-slate-10"
        >
          {{ t(`MACROS.VARIABLES.GROUPS.${group.key}`) }}
        </p>
        <button
          v-for="variable in group.variables"
          :key="variable.key"
          type="button"
          class="flex flex-col w-full px-3 py-1.5 text-start hover:bg-n-alpha-2"
          @click="select(variable.key)"
        >
          <span class="text-sm text-n-slate-12">
            {{ t(`MACROS.VARIABLES.${variable.label}`) }}
          </span>
          <span class="font-mono text-xs text-n-slate-10">
            {{ token(variable.key) }}
          </span>
        </button>
      </div>
    </div>
  </div>
</template>
