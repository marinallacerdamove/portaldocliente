<script setup>
// PATCH LOCAL (fork) - seção discreta dos contatos avulsos de um grupo
// (contatos adicionados um a um, fora de uma empresa). Mostra os que já estão
// e, pra quem edita, um link "Adicionar contato avulso" que abre a busca. Não
// grava nada: avisa (add/remove) e a tela manda tudo no Salvar.
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import PortalGroupActiveBadge from './PortalGroupActiveBadge.vue';
import PortalGroupMemberSearch from './PortalGroupMemberSearch.vue';

defineProps({
  // [{ id, primary, secondary, active }]
  rows: { type: Array, default: () => [] },
  // [{ id, primary, secondary }]
  candidates: { type: Array, default: () => [] },
  canEdit: { type: Boolean, default: false },
  isLoadingCandidates: { type: Boolean, default: false },
  candidatesError: { type: String, default: '' },
});

const emit = defineEmits(['add', 'remove', 'retry']);

const { t } = useI18n();
const isSearchOpen = ref(false);
</script>

<template>
  <section class="flex flex-col gap-2">
    <h3 class="my-0 text-sm font-medium text-n-slate-11">
      {{ t('PORTAL_GROUPS.INDIVIDUAL.TITLE', { count: rows.length }) }}
    </h3>

    <ul
      v-if="rows.length"
      class="flex flex-col pl-0 mb-0 list-none border divide-y rounded-lg border-n-weak divide-n-weak"
    >
      <li
        v-for="row in rows"
        :key="row.id"
        class="flex items-center justify-between gap-3 px-3 py-2"
      >
        <div class="flex flex-col min-w-0">
          <span class="text-sm truncate text-n-slate-12">{{
            row.primary
          }}</span>
          <span v-if="row.secondary" class="text-xs truncate text-n-slate-11">
            {{ row.secondary }}
          </span>
        </div>
        <div class="flex items-center gap-2 shrink-0">
          <PortalGroupActiveBadge :active="row.active" />
          <Button
            v-if="canEdit"
            icon="i-lucide-x"
            ghost
            slate
            xs
            type="button"
            :title="t('PORTAL_GROUPS.INDIVIDUAL.REMOVE')"
            @click="emit('remove', row.id)"
          />
        </div>
      </li>
    </ul>

    <template v-if="canEdit">
      <button
        v-if="!isSearchOpen"
        type="button"
        class="self-start text-sm text-n-blue-11 hover:underline"
        @click="isSearchOpen = true"
      >
        {{ t('PORTAL_GROUPS.INDIVIDUAL.ADD') }}
      </button>
      <PortalGroupMemberSearch
        v-else
        :candidates="candidates"
        :excluded-ids="rows.map(row => row.id)"
        :placeholder="t('PORTAL_GROUPS.INDIVIDUAL.SEARCH')"
        :is-loading="isLoadingCandidates"
        :error="candidatesError"
        @add="emit('add', $event)"
        @retry="emit('retry')"
      />
    </template>
  </section>
</template>
