<script setup>
// PATCH LOCAL (fork) - Assistente (IA com base na wiki). "Perguntar" pra todo
// atendente; base de conhecimento, respostas da equipe e histórico só pra
// administrador (o backend também barra).
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { usePortalAssistant } from 'dashboard/composables/usePortalAssistant';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import AssistantAsk from 'dashboard/components-next/PortalAssistant/AssistantAsk.vue';
import AssistantSources from 'dashboard/components-next/PortalAssistant/AssistantSources.vue';
import AssistantAnswers from 'dashboard/components-next/PortalAssistant/AssistantAnswers.vue';
import AssistantQuestions from 'dashboard/components-next/PortalAssistant/AssistantQuestions.vue';

const TABS = [
  { key: 'ask', label: 'PORTAL_ASSISTANT.TABS.ASK', adminOnly: false },
  {
    key: 'questions',
    label: 'PORTAL_ASSISTANT.TABS.QUESTIONS',
    adminOnly: true,
  },
  { key: 'answers', label: 'PORTAL_ASSISTANT.TABS.ANSWERS', adminOnly: true },
  { key: 'sources', label: 'PORTAL_ASSISTANT.TABS.SOURCES', adminOnly: true },
];

const { t } = useI18n();
const { isAdmin } = useAdmin();
const { isEnabled } = usePortalAssistant();

const visibleTabs = computed(() =>
  TABS.filter(tab => !tab.adminOnly || isAdmin.value)
);
const tabBarItems = computed(() =>
  visibleTabs.value.map(tab => ({ key: tab.key, label: t(tab.label) }))
);

const activeTabKey = ref('ask');
const activeTabIndex = computed(() =>
  visibleTabs.value.findIndex(tab => tab.key === activeTabKey.value)
);
const draftTitle = ref('');

const onTabChanged = tab => {
  activeTabKey.value = tab.key;
};

const createAnswerFrom = question => {
  draftTitle.value = question;
  activeTabKey.value = 'answers';
};
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="flex flex-col gap-1 px-6 pt-7 pb-4">
      <h1 class="my-0 text-xl font-semibold text-n-slate-12">
        {{ t('PORTAL_ASSISTANT.TITLE') }}
      </h1>
      <p class="mb-0 text-sm text-n-slate-11">
        {{ t('PORTAL_ASSISTANT.SUBTITLE') }}
      </p>
    </header>

    <main class="flex-1 px-6 pb-8 overflow-y-auto">
      <div class="flex flex-col w-full max-w-3xl gap-4">
        <p v-if="!isEnabled" class="mb-0 text-sm text-n-slate-11">
          {{ t('PORTAL_ASSISTANT.DISABLED') }}
        </p>

        <template v-else>
          <TabBar
            v-if="visibleTabs.length > 1"
            :tabs="tabBarItems"
            :initial-active-tab="activeTabIndex"
            @tab-changed="onTabChanged"
          />

          <AssistantAsk v-show="activeTabKey === 'ask'" />
          <AssistantQuestions
            v-if="activeTabKey === 'questions'"
            @create-answer="createAnswerFrom"
          />
          <AssistantAnswers
            v-if="activeTabKey === 'answers'"
            :draft-title="draftTitle"
            @draft-consumed="draftTitle = ''"
          />
          <AssistantSources v-if="activeTabKey === 'sources'" />
        </template>
      </div>
    </main>
  </section>
</template>
