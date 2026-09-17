<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { picoSearch } from '@chatwoot/pico-search';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import {
  useStore,
  useStoreGetters,
  useMapGetter,
} from 'dashboard/composables/store';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();
const { isAdmin } = useAdmin();

const searchQuery = ref('');
const loading = ref({});

const botFlows = useMapGetter('botFlows/getBotFlows');
const inboxes = useMapGetter('inboxes/getInboxes');
const uiFlags = computed(() => getters['botFlows/getUIFlags'].value);

const filteredBotFlows = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return botFlows.value;
  return picoSearch(botFlows.value, query, ['name', 'description']);
});

const inboxNameFor = id => inboxes.value.find(inbox => inbox.id === id)?.name;

const triggerLabelFor = flow => {
  if (flow.trigger_type === 'keyword') {
    const keywords = flow.trigger_config?.keywords || [];
    return t('BOT_FLOW.LIST.TRIGGER_KEYWORD', {
      keywords: keywords.join(', '),
    });
  }
  return t('BOT_FLOW.LIST.TRIGGER_CONVERSATION_CREATED');
};

onMounted(() => {
  store.dispatch('botFlows/get');
  if (!inboxes.value.length) store.dispatch('inboxes/get');
});

const toggleActive = async flow => {
  try {
    loading.value[flow.id] = true;
    await store.dispatch('botFlows/update', {
      id: flow.id,
      active: !flow.active,
    });
  } catch (error) {
    useAlert(t('BOT_FLOW.LIST.API.ERROR_MESSAGE'));
  } finally {
    loading.value[flow.id] = false;
  }
};

const showDeletePopup = ref(false);
const selectedFlow = ref({});

const openDelete = flow => {
  showDeletePopup.value = true;
  selectedFlow.value = flow;
};

const closeDelete = () => {
  showDeletePopup.value = false;
  selectedFlow.value = {};
};

const confirmDeletion = async () => {
  const flow = selectedFlow.value;
  closeDelete();
  try {
    loading.value[flow.id] = true;
    await store.dispatch('botFlows/delete', flow.id);
    useAlert(t('BOT_FLOW.LIST.DELETE.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('BOT_FLOW.LIST.DELETE.ERROR_MESSAGE'));
  } finally {
    loading.value[flow.id] = false;
  }
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="t('BOT_FLOW.LIST.LOADING')"
    :no-records-found="!botFlows.length"
    :no-records-message="t('BOT_FLOW.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="t('BOT_FLOW.HEADER')"
        :description="t('BOT_FLOW.DESCRIPTION')"
        :search-placeholder="t('BOT_FLOW.LIST.SEARCH_PLACEHOLDER')"
      >
        <template v-if="botFlows.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ t('BOT_FLOW.LIST.COUNT', { n: botFlows.length }) }}
          </span>
        </template>
        <template #actions>
          <router-link v-if="isAdmin" :to="{ name: 'bot_flows_new' }">
            <Button :label="t('BOT_FLOW.LIST.NEW_FLOW')" size="sm" />
          </router-link>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <span
        v-if="!filteredBotFlows.length && searchQuery"
        class="flex-1 flex items-center justify-center py-20 text-center text-body-main !text-base text-n-slate-11"
      >
        {{ t('BOT_FLOW.LIST.NO_RESULTS') }}
      </span>

      <div v-else class="divide-y divide-n-weak border-t border-n-weak">
        <div
          v-for="flow in filteredBotFlows"
          :key="flow.id"
          class="flex justify-between flex-row items-start gap-4 py-4"
        >
          <div class="flex items-start gap-4">
            <div
              class="flex items-center flex-shrink-0 size-10 justify-center rounded-xl outline outline-1 outline-n-weak -outline-offset-1"
            >
              <Icon icon="i-lucide-workflow" class="size-4 text-n-slate-11" />
            </div>
            <div class="flex flex-col items-start gap-1">
              <span class="block text-heading-3 text-n-slate-12">
                {{ flow.name }}
              </span>
              <p class="mb-0 text-n-slate-11 text-body-main">
                {{ triggerLabelFor(flow) }}
              </p>
              <p
                v-if="flow.inbox_ids?.length"
                class="mb-0 text-n-slate-11 text-body-main"
              >
                {{
                  flow.inbox_ids.map(inboxNameFor).filter(Boolean).join(', ')
                }}
              </p>
            </div>
          </div>
          <div class="flex items-center justify-end gap-3">
            <Switch
              v-if="isAdmin"
              v-model="flow.active"
              v-tooltip.top="t('BOT_FLOW.LIST.TOGGLE_ACTIVE')"
              @change="toggleActive(flow)"
            />
            <router-link
              :to="{ name: 'bot_flows_edit', params: { botFlowId: flow.id } }"
            >
              <Button
                v-if="isAdmin"
                v-tooltip.top="t('BOT_FLOW.LIST.EDIT')"
                icon="i-woot-settings"
                slate
                sm
              />
            </router-link>
            <Button
              v-if="isAdmin"
              v-tooltip.top="t('BOT_FLOW.LIST.DELETE.BUTTON_TEXT')"
              icon="i-woot-bin"
              slate
              sm
              class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
              :is-loading="loading[flow.id]"
              @click="openDelete(flow)"
            />
          </div>
        </div>
      </div>
    </template>
    <woot-confirm-delete-modal
      v-if="showDeletePopup"
      v-model:show="showDeletePopup"
      :title="
        t('BOT_FLOW.LIST.DELETE.CONFIRM.TITLE', { flowName: selectedFlow.name })
      "
      :message="t('BOT_FLOW.LIST.DELETE.CONFIRM.MESSAGE')"
      :confirm-text="`${t('BOT_FLOW.LIST.DELETE.CONFIRM.YES')} ${selectedFlow.name}`"
      :reject-text="t('BOT_FLOW.LIST.DELETE.CONFIRM.NO')"
      :confirm-value="selectedFlow.name"
      :confirm-place-holder-text="
        t('BOT_FLOW.LIST.DELETE.CONFIRM.PLACE_HOLDER', {
          flowName: selectedFlow.name,
        })
      "
      @on-confirm="confirmDeletion"
      @on-close="closeDelete"
    />
  </SettingsLayout>
</template>
