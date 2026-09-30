<script setup>
import { ref, nextTick, useTemplateRef } from 'vue';
import InlineInput from 'dashboard/components-next/inline-input/InlineInput.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  label: { type: String, required: true },
  value: { type: String, default: '' },
  editable: { type: Boolean, default: false },
  html: { type: Boolean, default: false },
});

const emit = defineEmits(['update']);

const isEditing = ref(false);
const editValue = ref('');
const editInput = useTemplateRef('editInput');

const startEditing = () => {
  if (!props.editable) return;
  editValue.value = props.value || '';
  isEditing.value = true;
  nextTick(() => editInput.value?.focus());
};

const saveEdit = () => {
  if (!isEditing.value) return;
  isEditing.value = false;
  const trimmed = editValue.value.trim();
  if (trimmed !== (props.value || '')) emit('update', trimmed);
};

const cancelEdit = () => {
  isEditing.value = false;
};
</script>

<template>
  <div class="flex flex-col gap-0.5 group/field">
    <span class="text-xs font-medium tracking-wide text-n-slate-10">
      {{ label }}
    </span>
    <InlineInput
      v-if="isEditing"
      ref="editInput"
      v-model="editValue"
      class="text-sm"
      @enter-press="saveEdit"
      @escape-press="cancelEdit"
      @blur="saveEdit"
    />
    <div v-else class="flex items-center gap-1.5 min-h-5">
      <span
        v-if="value && html"
        v-dompurify-html="value"
        class="text-sm text-n-slate-12"
      />
      <span v-else-if="value" class="text-sm break-words text-n-slate-12">
        {{ value }}
      </span>
      <span v-else class="text-sm text-n-slate-10">
        {{ $t('CONTACT_PANEL.NOT_AVAILABLE') }}
      </span>
      <NextButton
        v-if="editable"
        ghost
        xs
        slate
        class="opacity-0 group-hover/field:opacity-100 transition-opacity"
        icon="i-lucide-pencil"
        @click="startEditing"
      />
    </div>
  </div>
</template>
