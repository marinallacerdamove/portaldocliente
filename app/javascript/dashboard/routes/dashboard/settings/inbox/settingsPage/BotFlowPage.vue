<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import {
  useStore,
  useMapGetter,
  useFunctionGetter,
} from 'dashboard/composables/store';
import { useBotFlow } from 'dashboard/composables/useBotFlow';
import { isBotFlowStepValid } from 'dashboard/helper/botFlowHelper';
import NextButton from 'dashboard/components-next/button/Button.vue';
import BotFlowStepInput from 'dashboard/components/widgets/BotFlowStepInput.vue';

const props = defineProps({
  inbox: { type: Object, required: true },
});

const { t } = useI18n();
const store = useStore();

const {
  steps,
  setSteps,
  addStep,
  removeStep,
  moveStep,
  setStepType,
  updateStep,
} = useBotFlow(props.inbox.bot_flow_steps || []);

const isSaving = ref(false);

watch(
  () => props.inbox.id,
  () => setSteps(props.inbox.bot_flow_steps || [])
);

const conversationAttributes = useFunctionGetter(
  'attributes/getAttributesByModel',
  'conversation_attribute'
);
const cannedResponses = useMapGetter('cannedResponse/getCannedResponses');

const attributeOptions = computed(() =>
  conversationAttributes.value
    .filter(attribute => attribute.attribute_display_type === 'list')
    .map(attribute => ({
      id: attribute.attribute_key,
      name: attribute.attribute_display_name,
    }))
);

const cannedResponseOptions = computed(() =>
  cannedResponses.value.map(response => ({
    id: response.short_code,
    name: `${response.short_code} — ${response.content}`,
  }))
);

onMounted(() => {
  if (!conversationAttributes.value.length) store.dispatch('attributes/get');
  if (!cannedResponses.value.length) {
    store.dispatch('cannedResponse/getCannedResponse');
  }
});

const invalidStepIndexes = computed(() =>
  steps.value.reduce((indexes, step, index) => {
    if (!isBotFlowStepValid(step)) indexes.push(index);
    return indexes;
  }, [])
);

const saveFlow = async () => {
  if (invalidStepIndexes.value.length) {
    useAlert(t('INBOX_MGMT.BOT_FLOW.VALIDATION_ERROR'));
    return;
  }

  try {
    isSaving.value = true;
    await store.dispatch('inboxes/updateInbox', {
      id: props.inbox.id,
      formData: false,
      bot_flow_steps: steps.value,
    });
    useAlert(t('INBOX_MGMT.BOT_FLOW.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.BOT_FLOW.ERROR_MESSAGE'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div class="mx-6 max-w-4xl">
    <div class="mb-4">
      <h4 class="text-base font-medium text-n-slate-12">
        {{ t('INBOX_MGMT.BOT_FLOW.TITLE') }}
      </h4>
      <p class="text-sm text-n-slate-11">
        {{ t('INBOX_MGMT.BOT_FLOW.SUBTITLE') }}
      </p>
    </div>

    <div class="flex flex-col gap-4">
      <p v-if="!steps.length" class="text-sm text-n-slate-11">
        {{ t('INBOX_MGMT.BOT_FLOW.EMPTY_STATE') }}
      </p>

      <BotFlowStepInput
        v-for="(step, index) in steps"
        :key="index"
        :model-value="step"
        :attribute-options="attributeOptions"
        :canned-response-options="cannedResponseOptions"
        :is-first="index === 0"
        :is-last="index === steps.length - 1"
        @update:model-value="updatedStep => updateStep(index, updatedStep)"
        @change-type="type => setStepType(index, type)"
        @remove="removeStep(index)"
        @move-up="moveStep(index, -1)"
        @move-down="moveStep(index, 1)"
      />

      <div>
        <NextButton
          sm
          slate
          faded
          icon="i-lucide-plus"
          :label="t('INBOX_MGMT.BOT_FLOW.ADD_STEP')"
          @click="addStep"
        />
      </div>
    </div>

    <div class="flex justify-end mt-6">
      <NextButton
        :label="t('INBOX_MGMT.BOT_FLOW.SAVE')"
        :is-loading="isSaving"
        @click="saveFlow"
      />
    </div>
  </div>
</template>
