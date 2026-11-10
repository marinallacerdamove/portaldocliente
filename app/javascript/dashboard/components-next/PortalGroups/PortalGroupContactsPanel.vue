<script setup>
// PATCH LOCAL (fork) - o que aparece ao abrir um grupo na lista: botões
// "Vincular empresas" e "Adicionar contato" (administrador), as empresas
// vinculadas e os contatos do grupo (das empresas e avulsos) com empresa,
// telefone e situação calculada pelo Portal. Contato avulso tem × pra tirar
// do grupo; quem vem pela empresa sai desvinculando a empresa. Grupo
// automático mostra quem recebe.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PortalGroupContactStatusBadge from './PortalGroupContactStatusBadge.vue';

const props = defineProps({
  // detalhe do grupo como o Portal devolve (empresas com contatos, contatos
  // avulsos e, no automático, recipients)
  group: { type: Object, required: true },
  canEdit: { type: Boolean, default: false },
  busy: { type: Boolean, default: false },
});

const emit = defineEmits(['linkCompanies', 'addContacts', 'removeContact']);

const RECEIVES = 'recebe';
const NO_VALUE = '—';

const { t } = useI18n();

const byName = (first, second) =>
  first.name.localeCompare(second.name, undefined, { sensitivity: 'base' });

// Uma linha por contato: quem está em duas empresas aparece uma vez, com as
// duas, e recebe se receber por alguma delas.
const rows = computed(() => {
  if (props.group.automatic) {
    return (props.group.recipients || [])
      .map(recipient => ({
        id: recipient.partner_id,
        name: recipient.name,
        phone: recipient.phone,
        empresas: [],
        status: RECEIVES,
        individual: false,
      }))
      .sort(byName);
  }

  const byId = new Map();
  (props.group.empresas || []).forEach(empresa =>
    (empresa.contatos || []).forEach(contato => {
      const row = byId.get(contato.id);
      if (row) {
        row.empresas.push(empresa.nome);
        if (contato.status === RECEIVES) row.status = RECEIVES;
      } else {
        byId.set(contato.id, {
          ...contato,
          empresas: [empresa.nome],
          individual: false,
        });
      }
    })
  );
  (props.group.contatos || []).forEach(contato => {
    const row = byId.get(contato.id);
    if (row) row.individual = true;
    else byId.set(contato.id, { ...contato, empresas: [], individual: true });
  });
  return [...byId.values()].sort(byName);
});

const empresaNames = computed(() =>
  (props.group.empresas || []).map(empresa => empresa.nome).join(', ')
);

const origin = row => {
  if (row.empresas.length) return row.empresas.join(', ');
  return row.individual ? t('PORTAL_GROUPS.PANEL.INDIVIDUAL') : NO_VALUE;
};
</script>

<template>
  <div class="flex flex-col bg-n-alpha-1">
    <div
      v-if="!group.automatic"
      class="flex flex-wrap items-center gap-2 py-3 border-b ps-12 pe-4 border-n-weak"
    >
      <template v-if="canEdit">
        <Button
          :label="t('PORTAL_GROUPS.PANEL.LINK_COMPANIES')"
          icon="i-lucide-building-2"
          variant="outline"
          color="slate"
          size="sm"
          :disabled="busy"
          @click="emit('linkCompanies')"
        />
        <Button
          :label="t('PORTAL_GROUPS.PANEL.ADD_CONTACTS')"
          icon="i-lucide-user-plus"
          variant="outline"
          color="slate"
          size="sm"
          :disabled="busy"
          @click="emit('addContacts')"
        />
      </template>
      <span class="min-w-0 text-xs truncate text-n-slate-11 ms-auto">
        {{
          empresaNames
            ? t('PORTAL_GROUPS.PANEL.COMPANIES', { names: empresaNames })
            : t('PORTAL_GROUPS.PANEL.NO_COMPANIES')
        }}
      </span>
    </div>

    <div
      v-if="rows.length"
      class="grid grid-cols-[1.5rem_minmax(0,1fr)_minmax(0,14rem)_10rem_9rem_1.75rem] items-center gap-x-4 py-2 text-xs font-medium border-b ps-12 pe-4 text-n-slate-11 border-n-weak"
    >
      <span />
      <span>{{ t('PORTAL_GROUPS.PANEL.CONTACT') }}</span>
      <span>{{ t('PORTAL_GROUPS.PANEL.COMPANY') }}</span>
      <span>{{ t('PORTAL_GROUPS.PANEL.PHONE') }}</span>
      <span>{{ t('PORTAL_GROUPS.PANEL.STATUS') }}</span>
      <span />
    </div>

    <ul
      v-if="rows.length"
      class="flex flex-col pl-0 mb-0 list-none divide-y divide-n-weak"
    >
      <li
        v-for="row in rows"
        :key="row.id"
        class="grid grid-cols-[1.5rem_minmax(0,1fr)_minmax(0,14rem)_10rem_9rem_1.75rem] items-center gap-x-4 py-2 ps-12 pe-4 min-h-11"
      >
        <Avatar :name="row.name" :size="24" rounded-full />
        <span class="text-sm truncate text-n-slate-12">{{ row.name }}</span>
        <span class="text-sm truncate text-n-slate-11">{{ origin(row) }}</span>
        <span class="text-sm truncate text-n-slate-11">
          {{ row.phone || NO_VALUE }}
        </span>
        <span><PortalGroupContactStatusBadge :status="row.status" /></span>
        <span class="flex justify-end">
          <Button
            v-if="canEdit && row.individual"
            :title="t('PORTAL_GROUPS.PANEL.REMOVE_CONTACT')"
            icon="i-lucide-x"
            variant="ghost"
            color="slate"
            size="xs"
            :disabled="busy"
            @click="emit('removeContact', row.id)"
          />
        </span>
      </li>
    </ul>

    <p v-else class="py-4 mb-0 text-sm ps-12 pe-4 text-n-slate-11">
      {{
        group.automatic
          ? t('PORTAL_GROUPS.PANEL.EMPTY_AUTOMATIC')
          : t('PORTAL_GROUPS.PANEL.EMPTY')
      }}
    </p>
  </div>
</template>
