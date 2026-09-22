import { ref, nextTick } from 'vue';

// Detecta "{{" digitado antes do cursor (pra abrir o seletor de variáveis
// sozinho, sem exigir clicar em nada) e insere uma variável exatamente na
// posição do cursor - usado por VariableInput/VariableTextArea, que só
// diferem no elemento nativo (input x textarea).
export function useVariableAwareField(modelValue) {
  const fieldRef = ref(null);
  const pickerOpen = ref(false);
  const pickerQuery = ref('');
  // 'button': aberto pelo botão "+ Inserir dado" - insere no cursor sem
  // mexer no texto ao redor. 'brace': aberto ao digitar "{{" - precisa
  // substituir o "{{parcial" já digitado pela variável escolhida.
  const triggerMode = ref('button');

  const handleInput = () => {
    const el = fieldRef.value;
    if (!el) return;

    const textBeforeCursor = el.value.slice(0, el.selectionStart);
    const match = textBeforeCursor.match(/\{\{([\w.-]*)$/);

    if (match) {
      triggerMode.value = 'brace';
      pickerQuery.value = match[1];
      pickerOpen.value = true;
    } else if (pickerOpen.value && triggerMode.value === 'brace') {
      pickerOpen.value = false;
    }
  };

  const openPicker = () => {
    triggerMode.value = 'button';
    pickerQuery.value = '';
    pickerOpen.value = true;
  };

  const insertAtCursor = async id => {
    const el = fieldRef.value;
    if (!el) {
      modelValue.value = `${modelValue.value || ''}{{${id}}}`;
      pickerOpen.value = false;
      return;
    }

    const cursor = el.selectionStart ?? el.value.length;
    const textBeforeCursor = el.value.slice(0, cursor);
    const braceMatch =
      triggerMode.value === 'brace'
        ? textBeforeCursor.match(/\{\{[\w.-]*$/)
        : null;
    const matchStart = braceMatch
      ? textBeforeCursor.length - braceMatch[0].length
      : cursor;
    const before = el.value.slice(0, matchStart);
    const after = el.value.slice(cursor);

    modelValue.value = `${before}{{${id}}}${after}`;
    pickerOpen.value = false;

    await nextTick();
    const newCursor = before.length + id.length + 4;
    el.focus();
    el.setSelectionRange(newCursor, newCursor);
  };

  return {
    fieldRef,
    pickerOpen,
    pickerQuery,
    handleInput,
    openPicker,
    insertAtCursor,
  };
}
