<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import { createContactSearcher } from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper';

const emit = defineEmits(['update:contact']);
const { t } = useI18n();

const search = createContactSearcher();
const isSearching = ref(false);
const results = ref([]);
const selected = ref(null);

const options = computed(() =>
  results.value.map(contact => ({
    id: contact.id,
    name: contact.name,
    icon: 'i-lucide-user',
  }))
);

const runSearch = async query => {
  isSearching.value = true;
  const found = await search(query);
  if (found) results.value = found;
  isSearching.value = false;
};
const handleSearch = debounce(runSearch, 300);

watch(selected, option => {
  const contact = option
    ? results.value.find(c => c.id === option.id) || null
    : null;
  emit('update:contact', contact);
});
</script>

<template>
  <SingleSelect
    v-model="selected"
    :options="options"
    async-search
    :is-searching="isSearching"
    placeholder-icon="i-lucide-user-search"
    :placeholder="t('BOT_FLOW.EDITOR.SAMPLE_CONTACT.LABEL')"
    :search-placeholder="t('BOT_FLOW.EDITOR.SAMPLE_CONTACT.PLACEHOLDER')"
    @search="handleSearch"
  />
</template>
