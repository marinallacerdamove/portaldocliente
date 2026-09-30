<script setup>
// PATCH LOCAL (fork) - "Alterar campo do ticket" (set_custom_attribute), comum
// à macro e à automação. action_params = [chave do atributo de conversa, valor].
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const params = defineModel({ type: Array, default: () => [] });

const { t } = useI18n();

// Tipos de campo que a ação sabe preencher.
const EDITABLE_ATTRIBUTE_TYPES = ['list', 'text'];

const conversationAttributes = useMapGetter(
  'attributes/getConversationAttributes'
);
const attributeOptions = computed(() =>
  conversationAttributes.value
    .filter(attr =>
      EDITABLE_ATTRIBUTE_TYPES.includes(attr.attributeDisplayType)
    )
    .map(attr => ({
      id: attr.attributeKey,
      name: attr.attributeDisplayName,
    }))
);
const selectedAttribute = computed(() => {
  const key = params.value?.[0];
  if (!key) return null;
  return conversationAttributes.value.find(attr => attr.attributeKey === key);
});
const attributeModel = computed({
  get: () =>
    attributeOptions.value.find(option => option.id === params.value?.[0]) ||
    null,
  set: option => {
    params.value = option ? [option.id, ''] : [];
  },
});
const attributeValueOptions = computed(() =>
  (selectedAttribute.value?.attributeValues || []).map(value => ({
    id: value,
    name: value,
  }))
);
const attributeValue = computed({
  get: () => params.value?.[1] || '',
  set: value => {
    params.value = [params.value?.[0], value];
  },
});
const attributeValueModel = computed({
  get: () =>
    attributeValueOptions.value.find(
      option => option.id === attributeValue.value
    ) || null,
  set: option => {
    attributeValue.value = option?.id || '';
  },
});
</script>

<template>
  <div class="grid gap-2 sm:grid-cols-2">
    <div class="flex flex-col gap-1">
      <span class="text-xs text-n-slate-11">
        {{ t('MACROS.EDITOR.CUSTOM_ATTRIBUTE.FIELD') }}
      </span>
      <SingleSelect
        v-model="attributeModel"
        :options="attributeOptions"
        disable-deselect
      />
    </div>
    <div v-if="selectedAttribute" class="flex flex-col gap-1">
      <span class="text-xs text-n-slate-11">
        {{ t('MACROS.EDITOR.CUSTOM_ATTRIBUTE.VALUE') }}
      </span>
      <SingleSelect
        v-if="selectedAttribute.attributeDisplayType === 'list'"
        v-model="attributeValueModel"
        :options="attributeValueOptions"
        disable-deselect
      />
      <Input
        v-else
        v-model="attributeValue"
        size="sm"
        :placeholder="t('MACROS.EDITOR.CUSTOM_ATTRIBUTE.VALUE_PLACEHOLDER')"
      />
    </div>
  </div>
</template>
