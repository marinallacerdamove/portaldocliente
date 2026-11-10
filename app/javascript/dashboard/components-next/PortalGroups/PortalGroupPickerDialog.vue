<script setup>
// PATCH LOCAL (fork) - janela de escolher empresas ou contatos de um grupo:
// busca, "Selecionar todas" (vale pro que a busca mostra) e uma caixa por
// linha. Só o que já está no grupo vem marcado. Não grava nada: devolve a
// lista COMPLETA de ids marcados (confirm). O slot "top" recebe campos extras
// (ex.: nome do grupo novo).
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { picoSearch } from '@chatwoot/pico-search';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  confirmLabel: { type: String, required: true },
  searchPlaceholder: { type: String, default: '' },
  // [{ id, title, subtitle, info }]; a busca olha título e subtítulo
  items: { type: Array, default: () => [] },
  isLoadingItems: { type: Boolean, default: false },
  itemsError: { type: String, default: '' },
  errorMessage: { type: String, default: '' },
  isLoading: { type: Boolean, default: false },
  // trava o confirmar por outro motivo (ex.: nome vazio)
  canConfirm: { type: Boolean, default: true },
});

const emit = defineEmits(['confirm', 'retry']);

const { t } = useI18n();
const dialogRef = ref(null);
const query = ref('');
const selected = ref(new Set());

const visibleItems = computed(() => {
  const term = query.value.trim();
  return term
    ? picoSearch(props.items, term, ['title', 'subtitle'])
    : props.items;
});

const visibleSelectedCount = computed(
  () => visibleItems.value.filter(item => selected.value.has(item.id)).length
);

const allVisibleSelected = computed(
  () =>
    visibleItems.value.length > 0 &&
    visibleSelectedCount.value === visibleItems.value.length
);

const someVisibleSelected = computed(
  () => visibleSelectedCount.value > 0 && !allVisibleSelected.value
);

const toggle = id => {
  const next = new Set(selected.value);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  selected.value = next;
};

const toggleAllVisible = () => {
  const next = new Set(selected.value);
  const select = !allVisibleSelected.value;
  visibleItems.value.forEach(item =>
    select ? next.add(item.id) : next.delete(item.id)
  );
  selected.value = next;
};

const open = (selectedIds = []) => {
  query.value = '';
  selected.value = new Set(selectedIds);
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const confirm = () => {
  if (props.canConfirm) emit('confirm', [...selected.value]);
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="xl"
    :title="title"
    :description="description"
    :confirm-button-label="confirmLabel"
    :is-loading="isLoading"
    :disable-confirm-button="!canConfirm || isLoadingItems"
    @confirm="confirm"
  >
    <div class="flex flex-col gap-3">
      <slot name="top" />

      <Input
        v-model="query"
        type="search"
        size="sm"
        :placeholder="searchPlaceholder"
      />

      <div
        v-if="isLoadingItems"
        class="flex items-center gap-2 py-4 text-sm text-n-slate-11"
      >
        <Spinner :size="16" />
        {{ t('PORTAL_GROUPS.PICKER.LOADING') }}
      </div>

      <div v-else-if="itemsError" class="flex flex-col items-start gap-2 py-2">
        <p class="mb-0 text-sm text-n-ruby-11">{{ itemsError }}</p>
        <Button
          :label="t('PORTAL_GROUPS.RETRY')"
          variant="faded"
          color="slate"
          size="xs"
          type="button"
          @click="emit('retry')"
        />
      </div>

      <template v-else>
        <label
          class="grid grid-cols-[1rem_minmax(0,1fr)_auto] items-center gap-x-3 px-1 pb-2 border-b cursor-pointer border-n-weak"
        >
          <Checkbox
            :model-value="allVisibleSelected"
            :indeterminate="someVisibleSelected"
            :disabled="!visibleItems.length"
            @change="toggleAllVisible"
          />
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('PORTAL_GROUPS.PICKER.SELECT_ALL') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{
              t(
                'PORTAL_GROUPS.PICKER.SELECTED',
                { count: selected.size },
                selected.size
              )
            }}
          </span>
        </label>

        <ul
          v-if="visibleItems.length"
          class="flex flex-col pl-0 mb-0 overflow-y-auto list-none divide-y max-h-80 divide-n-weak"
        >
          <li v-for="item in visibleItems" :key="item.id">
            <label
              class="grid grid-cols-[1rem_2rem_minmax(0,1fr)_auto] items-center gap-x-3 px-1 py-2 cursor-pointer"
            >
              <Checkbox
                :model-value="selected.has(item.id)"
                @change="toggle(item.id)"
              />
              <Avatar :name="item.title" :size="28" rounded-full />
              <span class="flex flex-col min-w-0">
                <span class="text-sm truncate text-n-slate-12">
                  {{ item.title }}
                </span>
                <span
                  v-if="item.subtitle"
                  class="text-xs truncate text-n-slate-11"
                >
                  {{ item.subtitle }}
                </span>
              </span>
              <span class="text-xs whitespace-nowrap text-n-slate-11">
                {{ item.info }}
              </span>
            </label>
          </li>
        </ul>
        <p v-else class="py-2 mb-0 text-sm text-n-slate-11">
          {{
            query.trim()
              ? t('PORTAL_GROUPS.PICKER.NO_MATCH')
              : t('PORTAL_GROUPS.PICKER.EMPTY')
          }}
        </p>
      </template>

      <p v-if="errorMessage" class="mb-0 text-sm text-n-ruby-11">
        {{ errorMessage }}
      </p>
    </div>
  </Dialog>
</template>
