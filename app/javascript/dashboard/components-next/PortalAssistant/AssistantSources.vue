<script setup>
// PATCH LOCAL (fork) - aba "Base de conhecimento" do Assistente (só admin):
// situação da sincronização com a wiki e quais áreas entram nas respostas.
import { computed, onMounted, onBeforeUnmount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import PortalAssistantAPI from 'dashboard/api/portalAssistant';
import { usePortalAssistant } from 'dashboard/composables/usePortalAssistant';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import InfoCardFields from 'dashboard/components-next/InfoCard/InfoCardFields.vue';

const POLL_INTERVAL_MS = 5000;

const { t } = useI18n();
const { formatDate, errorMessage } = usePortalAssistant();

const status = ref(null);
const areas = ref([]);
const isLoading = ref(true);
const loadError = ref('');
const isStarting = ref(false);
let pollTimer = null;

const stopPolling = () => {
  clearInterval(pollTimer);
  pollTimer = null;
};

const fetchStatus = async () => {
  const { data } = await PortalAssistantAPI.getSync();
  status.value = data;
  if (!data.running) stopPolling();
};

const fetchAreas = async () => {
  const { data } = await PortalAssistantAPI.getAreas();
  areas.value = data.data;
};

const startPolling = () => {
  if (pollTimer) return;
  pollTimer = setInterval(async () => {
    const wasRunning = status.value?.running;
    await fetchStatus().catch(stopPolling);
    // Terminou agora: a sincronização pode ter criado áreas novas.
    if (wasRunning && !status.value?.running) fetchAreas().catch(() => {});
  }, POLL_INTERVAL_MS);
};

const load = async () => {
  isLoading.value = true;
  loadError.value = '';
  try {
    await Promise.all([fetchStatus(), fetchAreas()]);
    if (status.value.running) startPolling();
  } catch (error) {
    loadError.value = errorMessage(
      error,
      t('PORTAL_ASSISTANT.SOURCES.LOAD_ERROR')
    );
  } finally {
    isLoading.value = false;
  }
};

const startSync = async () => {
  isStarting.value = true;
  try {
    await PortalAssistantAPI.startSync();
    useAlert(t('PORTAL_ASSISTANT.SOURCES.SYNC_STARTED'));
    status.value = { ...status.value, running: true };
    startPolling();
  } catch (error) {
    useAlert(errorMessage(error, t('PORTAL_ASSISTANT.SOURCES.SYNC_ERROR')));
  } finally {
    isStarting.value = false;
  }
};

const toggleArea = async (area, included) => {
  const previous = area.included;
  area.included = included;
  try {
    await PortalAssistantAPI.updateArea(area.id, included);
  } catch (error) {
    area.included = previous;
    useAlert(errorMessage(error, t('PORTAL_ASSISTANT.SOURCES.AREA_ERROR')));
  }
};

const lastRun = computed(() => status.value?.last_run);

const lastRunLabel = computed(() => {
  if (!lastRun.value) return t('PORTAL_ASSISTANT.SOURCES.NEVER');
  const date = formatDate(
    lastRun.value.finished_at || lastRun.value.created_at
  );
  const state = t(`PORTAL_ASSISTANT.SOURCES.STATUS.${lastRun.value.status}`);
  return `${t('PORTAL_ASSISTANT.SOURCES.LAST_RUN', { date })} · ${state}`;
});

const statusItems = computed(() => [
  {
    key: 'pages',
    label: t('PORTAL_ASSISTANT.SOURCES.PAGES'),
    value: String(lastRun.value?.pages_seen ?? ''),
  },
  {
    key: 'updated',
    label: t('PORTAL_ASSISTANT.SOURCES.UPDATED'),
    value: String(lastRun.value?.pages_updated ?? ''),
  },
  {
    key: 'searchable',
    label: t('PORTAL_ASSISTANT.SOURCES.SEARCHABLE'),
    value: String(status.value?.documents.searchable ?? ''),
  },
  {
    key: 'pending',
    label: t('PORTAL_ASSISTANT.SOURCES.PENDING'),
    value: String(status.value?.documents.pending ?? ''),
  },
]);

onMounted(load);
onBeforeUnmount(stopPolling);
</script>

<template>
  <div class="flex flex-col gap-4">
    <div
      v-if="isLoading"
      class="flex items-center gap-2 py-8 text-sm text-n-slate-11"
    >
      <Spinner :size="16" />
    </div>

    <p v-else-if="loadError" class="mb-0 text-sm text-n-ruby-11">
      {{ loadError }}
    </p>

    <template v-else>
      <div
        v-if="!status.ai_configured || !status.wiki_configured"
        class="flex flex-col gap-1 px-3 py-2 text-sm border rounded-xl bg-n-amber-3 border-n-amber-4 text-n-amber-11"
      >
        <span v-if="!status.ai_configured">
          {{ t('PORTAL_ASSISTANT.SOURCES.AI_NOT_CONFIGURED') }}
        </span>
        <span v-if="!status.wiki_configured">
          {{ t('PORTAL_ASSISTANT.SOURCES.WIKI_NOT_CONFIGURED') }}
        </span>
      </div>

      <InfoCard
        :title="t('PORTAL_ASSISTANT.SOURCES.STATUS_TITLE')"
        icon="i-lucide-refresh-cw"
      >
        <template #actions>
          <Button
            :label="
              status.running
                ? t('PORTAL_ASSISTANT.SOURCES.RUNNING')
                : t('PORTAL_ASSISTANT.SOURCES.SYNC_NOW')
            "
            icon="i-lucide-refresh-cw"
            faded
            slate
            xs
            :is-loading="isStarting || status.running"
            :disabled="isStarting || status.running"
            @click="startSync"
          />
        </template>
        <div class="flex flex-col gap-4">
          <p class="mb-0 text-sm text-n-slate-11">{{ lastRunLabel }}</p>
          <p
            v-if="lastRun?.error"
            class="mb-0 text-xs break-words text-n-amber-11"
          >
            {{ lastRun.error }}
          </p>
          <InfoCardFields :items="statusItems" />
        </div>
      </InfoCard>

      <InfoCard
        :title="t('PORTAL_ASSISTANT.SOURCES.AREAS_TITLE')"
        icon="i-lucide-folder-tree"
      >
        <template #actions>
          <span />
        </template>
        <div class="flex flex-col gap-3">
          <p class="mb-0 text-xs text-n-slate-11">
            {{ t('PORTAL_ASSISTANT.SOURCES.AREAS_HINT') }}
          </p>
          <p v-if="!areas.length" class="mb-0 text-sm text-n-slate-10">
            {{ t('PORTAL_ASSISTANT.SOURCES.AREAS_EMPTY') }}
          </p>
          <ul
            v-else
            class="flex flex-col p-0 m-0 list-none divide-y divide-n-weak"
          >
            <li
              v-for="area in areas"
              :key="area.id"
              class="flex items-center justify-between gap-3 py-2"
            >
              <div class="flex flex-col min-w-0">
                <span
                  class="text-sm truncate"
                  :class="area.included ? 'text-n-slate-12' : 'text-n-slate-10'"
                >
                  {{ area.name }}
                </span>
                <span class="text-xs text-n-slate-10">
                  {{
                    t('PORTAL_ASSISTANT.SOURCES.AREA_PAGES', {
                      count: area.documents_count,
                    })
                  }}
                </span>
              </div>
              <div class="flex items-center gap-2 shrink-0">
                <span
                  class="text-xs"
                  :class="area.included ? 'text-n-teal-11' : 'text-n-slate-10'"
                >
                  {{
                    area.included
                      ? t('PORTAL_ASSISTANT.SOURCES.AREA_ON')
                      : t('PORTAL_ASSISTANT.SOURCES.AREA_OFF')
                  }}
                </span>
                <Switch
                  :model-value="area.included"
                  @update:model-value="value => toggleArea(area, value)"
                />
              </div>
            </li>
          </ul>
        </div>
      </InfoCard>
    </template>
  </div>
</template>
