<script setup>
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

// PATCH LOCAL (fork) - card de uma seção de ficha (empresa, contato), no mesmo
// padrão das fichas do Portal: leitura por padrão (slot default), o lápis
// troca só este card pra edição (slot #edit) com Cancelar/Salvar próprios.
// Slot #actions substitui o lápis (card sem edição, ou com outra ação).
// Sem overflow-hidden: menus e listas suspensas dentro do card não podem ser
// cortados pela borda.
defineProps({
  title: { type: String, required: true },
  icon: { type: String, required: true },
  isEditing: { type: Boolean, default: false },
  canEdit: { type: Boolean, default: true },
  isSaving: { type: Boolean, default: false },
  saveDisabled: { type: Boolean, default: false },
});

const emit = defineEmits(['edit', 'cancel', 'save']);
const { t } = useI18n();
</script>

<template>
  <section
    class="w-full border shadow-sm rounded-xl border-n-weak bg-n-solid-1"
  >
    <header
      class="flex items-center justify-between gap-2 px-4 py-3 border-b border-n-weak"
    >
      <div class="flex items-center min-w-0 gap-2">
        <Icon :icon="icon" class="size-4 shrink-0 text-n-slate-10" />
        <h4 class="my-0 text-sm font-semibold truncate text-n-slate-12">
          {{ title }}
        </h4>
      </div>
      <!-- #actions troca o lápis por outras ações (card só de leitura). -->
      <slot name="actions">
        <Button
          v-if="!isEditing"
          v-tooltip.top="t('INFO_CARD.EDIT')"
          icon="i-lucide-pencil"
          ghost
          slate
          xs
          :disabled="!canEdit"
          @click="emit('edit')"
        />
      </slot>
    </header>

    <div class="px-4 py-4">
      <slot v-if="isEditing" name="edit" />
      <slot v-else />
    </div>

    <footer
      v-if="isEditing"
      class="flex items-center justify-end gap-2 px-4 py-3 border-t border-n-weak"
    >
      <Button
        :label="t('INFO_CARD.CANCEL')"
        ghost
        slate
        sm
        :disabled="isSaving"
        @click="emit('cancel')"
      />
      <Button
        :label="t('INFO_CARD.SAVE')"
        sm
        :is-loading="isSaving"
        :disabled="saveDisabled || isSaving"
        @click="emit('save')"
      />
    </footer>
  </section>
</template>
