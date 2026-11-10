<script setup>
// PATCH LOCAL (fork) - bloco de uma empresa dentro do grupo: nome, "X de Y
// recebem", botão de tirar e, logo abaixo, os contatos dela com a situação de
// cada um (como o Portal calcula). Contato novo da empresa entra sozinho;
// contato inativado aparece como "não recebe". Empresa inativa: todos os
// contatos vêm inativos.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import PortalGroupContactStatusBadge from './PortalGroupContactStatusBadge.vue';

const props = defineProps({
  // { id, nome, cnpj, active, contatos_count, recebem_count, contatos: [{ id, name, phone, status }] }
  empresa: { type: Object, required: true },
  canEdit: { type: Boolean, default: false },
});

const emit = defineEmits(['remove']);

const { t } = useI18n();

const subtitle = computed(() =>
  [
    props.empresa.cnpj,
    t('PORTAL_GROUPS.COMPANY.RECEIVE_OF', {
      receive: props.empresa.recebem_count,
      total: props.empresa.contatos_count,
    }),
  ]
    .filter(Boolean)
    .join(' · ')
);
</script>

<template>
  <section class="border rounded-xl border-n-weak bg-n-solid-1">
    <header
      class="flex items-center justify-between gap-3 px-4 py-3 border-b border-n-weak"
    >
      <div class="flex flex-col min-w-0 gap-0.5">
        <div class="flex items-center min-w-0 gap-2">
          <h3 class="my-0 text-sm font-semibold truncate text-n-slate-12">
            {{ empresa.nome }}
          </h3>
          <span
            v-if="!empresa.active"
            class="px-2 py-0.5 text-xs font-medium rounded-md shrink-0 bg-n-slate-3 text-n-slate-11"
          >
            {{ t('PORTAL_GROUPS.COMPANY.INACTIVE') }}
          </span>
        </div>
        <span class="text-xs text-n-slate-11">{{ subtitle }}</span>
      </div>
      <Button
        v-if="canEdit"
        :label="t('PORTAL_GROUPS.COMPANY.REMOVE')"
        icon="i-lucide-x"
        variant="ghost"
        color="slate"
        size="xs"
        type="button"
        @click="emit('remove', empresa.id)"
      />
    </header>

    <ul
      v-if="empresa.contatos?.length"
      class="flex flex-col pl-0 mb-0 overflow-y-auto list-none divide-y max-h-72 divide-n-weak"
    >
      <li
        v-for="contato in empresa.contatos"
        :key="contato.id"
        class="flex items-center justify-between gap-3 px-4 py-2"
      >
        <div class="flex flex-col min-w-0">
          <span class="text-sm truncate text-n-slate-12">
            {{ contato.name }}
          </span>
          <span class="text-xs truncate text-n-slate-11">
            {{ contato.phone || t('PORTAL_GROUPS.COMPANY.NO_PHONE') }}
          </span>
        </div>
        <PortalGroupContactStatusBadge :status="contato.status" />
      </li>
    </ul>
    <p v-else class="px-4 py-3 mb-0 text-sm text-n-slate-11">
      {{ t('PORTAL_GROUPS.COMPANY.NO_CONTACTS') }}
    </p>
  </section>
</template>
