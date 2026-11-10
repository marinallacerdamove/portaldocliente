<script setup>
// PATCH LOCAL (fork) - linha de uma empresa na ficha do grupo: caixa (entra ou
// sai do grupo inteira), nome, CNPJ, "X de Y recebem" e, ao clicar na linha,
// os contatos dela logo abaixo, com telefone e situação (como o Portal
// calcula). Contato novo da empresa entra sozinho; inativado para de receber.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import PortalGroupContactRow from './PortalGroupContactRow.vue';
import PortalGroupRow from './PortalGroupRow.vue';

const props = defineProps({
  // { id, nome, cnpj, active, contatos_count, recebem_count, contatos: [{ id, name, phone, status }] }
  empresa: { type: Object, required: true },
  checked: { type: Boolean, default: false },
  canEdit: { type: Boolean, default: false },
  expanded: { type: Boolean, default: false },
});

const emit = defineEmits(['toggle', 'expand']);

const { t } = useI18n();

const contatos = computed(() => props.empresa.contatos || []);

// No grupo: quantos recebem; fora dele: só quantos contatos tem.
const info = computed(() =>
  props.checked
    ? t('PORTAL_GROUPS.COMPANY.RECEIVE_OF', {
        receive: props.empresa.recebem_count,
        total: props.empresa.contatos_count,
      })
    : t(
        'PORTAL_GROUPS.COMPANY.CONTACTS',
        { count: props.empresa.contatos_count },
        props.empresa.contatos_count
      )
);

const expand = () => emit('expand', props.empresa.id);
</script>

<template>
  <div>
    <PortalGroupRow
      interactive
      role="button"
      tabindex="0"
      :aria-expanded="expanded"
      @click="expand"
      @keydown.enter="expand"
    >
      <template #check>
        <Checkbox
          v-if="canEdit"
          :model-value="checked"
          @click.stop
          @change="emit('toggle', empresa.id)"
        />
      </template>
      <template #avatar>
        <Avatar :name="empresa.nome" :size="32" rounded-full />
      </template>
      <span class="text-sm font-medium truncate text-n-slate-12">
        {{ empresa.nome }}
      </span>
      <span class="text-xs truncate text-n-slate-11">
        {{ empresa.cnpj || t('PORTAL_GROUPS.COMPANY.NO_DOCUMENT') }}
      </span>
      <template #info>{{ info }}</template>
      <template #status>
        <span
          v-if="!empresa.active"
          class="px-2 py-0.5 text-xs font-medium rounded-md whitespace-nowrap bg-n-slate-3 text-n-slate-11"
        >
          {{ t('PORTAL_GROUPS.COMPANY.INACTIVE') }}
        </span>
      </template>
      <template #end>
        <span
          class="i-lucide-chevron-right size-4 transition-transform"
          :class="{ 'rotate-90': expanded }"
        />
      </template>
    </PortalGroupRow>

    <template v-if="expanded">
      <PortalGroupContactRow
        v-for="contato in contatos"
        :key="contato.id"
        :contato="contato"
        nested
      />
      <PortalGroupRow v-if="!contatos.length" nested>
        <span class="text-sm text-n-slate-11">
          {{ t('PORTAL_GROUPS.COMPANY.NO_CONTACTS') }}
        </span>
      </PortalGroupRow>
    </template>
  </div>
</template>
