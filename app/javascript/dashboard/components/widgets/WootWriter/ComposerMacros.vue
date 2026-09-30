<script setup>
// PATCH LOCAL (fork) - botão "Macros" no editor de resposta: busca por nome
// ou grupo, lista agrupada. Quem executa é o ReplyBox (onExecuteMacro), que
// já trata o modal de atributos obrigatórios ao resolver.
import { computed, onMounted, ref, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import { picoSearch } from '@chatwoot/pico-search';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import { compareMacroGroups } from 'dashboard/routes/dashboard/settings/macros/macroHelper';

defineProps({
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['execute']);

const { t } = useI18n();
const store = useStore();
const { accountScopedRoute } = useAccount();
const macros = useMapGetter('macros/getMacros');

const isOpen = ref(false);
const toggleRef = ref(null);
const searchRef = ref(null);
const query = ref('');

const groupedMacros = computed(() => {
  const text = query.value.trim();
  const list = text
    ? picoSearch(macros.value, text, ['name', 'group_name'])
    : macros.value;
  const groups = new Map();
  [...list]
    .sort((a, b) => a.name.localeCompare(b.name))
    .forEach(macro => {
      const group = macro.group_name || '';
      if (!groups.has(group)) groups.set(group, []);
      groups.get(group).push(macro);
    });
  return [...groups.entries()]
    .sort(([a], [b]) => compareMacroGroups(a, b))
    .map(([name, items]) => ({ name, items }));
});

const close = () => {
  isOpen.value = false;
  query.value = '';
};

const toggle = async () => {
  isOpen.value = !isOpen.value;
  if (!isOpen.value) return;
  await nextTick();
  searchRef.value?.focus();
};

const select = macro => {
  emit('execute', macro);
  close();
};

onMounted(() => {
  if (!macros.value.length) store.dispatch('macros/get');
});
</script>

<template>
  <div class="relative">
    <Button
      ref="toggleRef"
      v-tooltip.top="t('MACROS.PICKER.TOOLTIP')"
      ghost
      sm
      icon="i-lucide-zap"
      :disabled="disabled"
      :class="isOpen ? 'text-n-amber-11 bg-n-alpha-2' : 'text-n-amber-11'"
      @click="toggle"
    />
    <div
      v-if="isOpen"
      v-on-click-outside="[close, { ignore: [toggleRef] }]"
      class="absolute z-50 flex flex-col w-[22rem] max-w-[calc(100vw-2rem)] max-h-[60vh] mb-2 overflow-hidden border shadow-lg ltr:right-0 rtl:left-0 bottom-full rounded-xl border-n-weak bg-n-solid-1"
    >
      <div class="p-2 border-b border-n-weak">
        <input
          id="composer-macro-search"
          ref="searchRef"
          v-model="query"
          type="search"
          :placeholder="t('MACROS.PICKER.SEARCH')"
          class="w-full px-3 py-1.5 mb-0 text-sm border rounded-lg border-n-weak bg-n-alpha-black2 text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
          @keydown.esc="close"
        />
      </div>
      <div class="flex-1 py-1 overflow-y-auto">
        <p
          v-if="!groupedMacros.length"
          class="px-3 py-4 mb-0 text-sm text-n-slate-10"
        >
          {{ t('MACROS.PICKER.EMPTY') }}
        </p>
        <div v-for="group in groupedMacros" :key="group.name" class="py-1">
          <p
            class="px-3 pt-1 pb-0.5 mb-0 text-xs font-medium uppercase tracking-wide text-n-slate-10"
          >
            {{ group.name || t('MACROS.PICKER.NO_GROUP') }}
          </p>
          <button
            v-for="macro in group.items"
            :key="macro.id"
            type="button"
            class="block w-full px-3 py-1.5 text-sm text-start truncate text-n-slate-12 hover:bg-n-alpha-2"
            @click="select(macro)"
          >
            {{ macro.name }}
          </button>
        </div>
      </div>
      <router-link
        :to="accountScopedRoute('macros_wrapper')"
        class="px-3 py-2 text-xs border-t border-n-weak text-n-blue-11 hover:underline"
        @click="close"
      >
        {{ t('MACROS.PICKER.MANAGE') }}
      </router-link>
    </div>
  </div>
</template>
