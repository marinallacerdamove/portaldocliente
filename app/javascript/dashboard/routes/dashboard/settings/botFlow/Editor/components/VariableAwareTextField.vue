<script setup>
import { ref, computed, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  multiline: { type: Boolean, default: false },
  rows: { type: Number, default: 3 },
  placeholder: { type: String, default: '' },
  variableOptions: { type: Array, default: () => [] },
  monospace: { type: Boolean, default: false },
});

const modelValue = defineModel({ type: String, default: '' });
const { t } = useI18n();

const fieldRef = ref(null);
const showSuggestions = ref(false);
const query = ref('');

const filteredOptions = computed(() =>
  props.variableOptions.filter(option =>
    option.id.toLowerCase().includes(query.value.toLowerCase())
  )
);

// Detecta se o texto antes do cursor termina em "{{algumacoisa" - se sim,
// abre a lista de variáveis disponíveis pra clicar em vez de digitar de
// cabeça (e errar o nome).
const handleInput = () => {
  const el = fieldRef.value;
  if (!el) return;

  const textBeforeCursor = el.value.slice(0, el.selectionStart);
  const match = textBeforeCursor.match(/\{\{(\w*)$/);

  if (match) {
    query.value = match[1];
    showSuggestions.value = true;
  } else {
    showSuggestions.value = false;
  }
};

const insertVariable = async option => {
  const el = fieldRef.value;
  if (!el) return;

  const cursor = el.selectionStart;
  const textBeforeCursor = el.value.slice(0, cursor);
  const matchStart = textBeforeCursor.search(/\{\{\w*$/);
  const before = el.value.slice(0, matchStart);
  const after = el.value.slice(cursor);

  modelValue.value = `${before}{{${option.id}}}${after}`;
  showSuggestions.value = false;

  await nextTick();
  const newCursor = before.length + option.id.length + 4;
  el.focus();
  el.setSelectionRange(newCursor, newCursor);
};

// Inserção pelos botões sempre visíveis - não depende de já ter digitado
// "{{" (esse é o único jeito de descobrir a lista sem digitar de cabeça).
const appendVariable = async option => {
  const el = fieldRef.value;
  if (!el) return;

  const cursor = el.selectionStart ?? el.value.length;
  const before = el.value.slice(0, cursor);
  const after = el.value.slice(cursor);

  modelValue.value = `${before}{{${option.id}}}${after}`;
  showSuggestions.value = false;

  await nextTick();
  const newCursor = before.length + option.id.length + 4;
  el.focus();
  el.setSelectionRange(newCursor, newCursor);
};

const handleBlur = () => {
  // Delay pra permitir o clique numa opção da lista antes de fechar.
  setTimeout(() => {
    showSuggestions.value = false;
  }, 150);
};
</script>

<template>
  <div class="relative">
    <textarea
      v-if="multiline"
      ref="fieldRef"
      v-model="modelValue"
      :rows="rows"
      :placeholder="placeholder"
      class="w-full reset-base rounded-lg border border-n-weak bg-n-solid-1 p-2 text-sm"
      :class="{ 'font-mono': monospace }"
      @input="handleInput"
      @blur="handleBlur"
    />
    <input
      v-else
      ref="fieldRef"
      v-model="modelValue"
      type="text"
      :placeholder="placeholder"
      class="w-full reset-base rounded-lg border border-n-weak bg-n-solid-1 p-2 text-sm h-9"
      :class="{ 'font-mono': monospace }"
      @input="handleInput"
      @blur="handleBlur"
    />

    <div
      v-if="showSuggestions && filteredOptions.length"
      class="absolute z-20 top-full mt-1 w-full max-h-40 overflow-y-auto rounded-lg border border-n-weak bg-n-solid-1 shadow-lg"
    >
      <button
        v-for="option in filteredOptions"
        :key="option.id"
        type="button"
        class="block w-full text-start px-3 py-1.5 text-xs text-n-slate-12 hover:bg-n-slate-3"
        @mousedown.prevent="insertVariable(option)"
      >
        {{ option.name }}
      </button>
    </div>
    <p
      v-if="showSuggestions && !filteredOptions.length"
      class="absolute z-20 top-full mt-1 w-full rounded-lg border border-n-weak bg-n-solid-1 shadow-lg px-3 py-1.5 text-xs text-n-slate-10"
    >
      {{ t('BOT_FLOW.EDITOR.VARIABLE_PICKER.EMPTY') }}
    </p>

    <!-- Lista sempre visível das variáveis disponíveis - digitar "{{" pra
    abrir o autocomplete não é algo que uma pessoa não técnica descobre
    sozinha, então oferecemos os mesmos botões sem exigir digitar nada. -->
    <div v-if="variableOptions.length" class="flex flex-wrap items-center gap-1 mt-1.5">
      <span class="text-xs text-n-slate-10">{{
        t('BOT_FLOW.EDITOR.VARIABLE_PICKER.AVAILABLE_LABEL')
      }}</span>
      <button
        v-for="option in variableOptions"
        :key="option.id"
        type="button"
        class="px-2 py-0.5 rounded-md bg-n-slate-2 hover:bg-n-slate-3 text-xs text-n-slate-12"
        @mousedown.prevent="appendVariable(option)"
      >
        {{ option.name }}
      </button>
    </div>
  </div>
</template>
