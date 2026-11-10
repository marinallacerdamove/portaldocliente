<script setup>
// PATCH LOCAL (fork) - linha de um contato na ficha do grupo: caixa (entra ou
// sai como avulso), nome, telefone e a situação calculada pelo Portal. Dentro
// de uma empresa aberta vem sem caixa (nested).
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import PortalGroupContactStatusBadge from './PortalGroupContactStatusBadge.vue';
import PortalGroupRow from './PortalGroupRow.vue';

const props = defineProps({
  // { id, name, phone, status }
  contato: { type: Object, required: true },
  checked: { type: Boolean, default: false },
  canEdit: { type: Boolean, default: false },
  nested: { type: Boolean, default: false },
  subtitle: { type: String, default: '' },
});

const emit = defineEmits(['toggle']);

const NO_VALUE = '—';

const toggle = () => {
  if (props.canEdit) emit('toggle', props.contato.id);
};
</script>

<template>
  <PortalGroupRow :nested="nested" :interactive="canEdit" @click="toggle">
    <template #check>
      <Checkbox
        v-if="canEdit"
        :model-value="checked"
        @click.stop
        @change="toggle"
      />
    </template>
    <template #avatar>
      <Avatar :name="contato.name" :size="nested ? 24 : 32" rounded-full />
    </template>
    <span
      class="text-sm truncate text-n-slate-12"
      :class="{ 'font-medium': !nested }"
    >
      {{ contato.name }}
    </span>
    <span v-if="subtitle" class="text-xs truncate text-n-slate-11">
      {{ subtitle }}
    </span>
    <!-- Sem telefone: a etiqueta de situação já diz. -->
    <template #info>{{ contato.phone || NO_VALUE }}</template>
    <template #status>
      <PortalGroupContactStatusBadge :status="contato.status" />
    </template>
  </PortalGroupRow>
</template>
