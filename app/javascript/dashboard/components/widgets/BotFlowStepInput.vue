<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import { BOT_FLOW_STEP_TYPES } from 'dashboard/helper/botFlowHelper';

const props = defineProps({
  modelValue: { type: Object, required: true },
  attributeOptions: { type: Array, default: () => [] },
  cannedResponseOptions: { type: Array, default: () => [] },
  isFirst: { type: Boolean, default: false },
  isLast: { type: Boolean, default: false },
});

const emit = defineEmits([
  'update:modelValue',
  'changeType',
  'remove',
  'moveUp',
  'moveDown',
]);

const { t } = useI18n();

const stepTypeOptions = computed(() => [
  {
    id: BOT_FLOW_STEP_TYPES.MENU,
    name: t('INBOX_MGMT.BOT_FLOW.STEP_TYPES.MENU'),
  },
  {
    id: BOT_FLOW_STEP_TYPES.ASK_AND_EXTRACT,
    name: t('INBOX_MGMT.BOT_FLOW.STEP_TYPES.ASK_AND_EXTRACT'),
  },
  {
    id: BOT_FLOW_STEP_TYPES.MESSAGE,
    name: t('INBOX_MGMT.BOT_FLOW.STEP_TYPES.MESSAGE'),
  },
]);

const updateField = (field, value) => {
  emit('update:modelValue', { ...props.modelValue, [field]: value });
};

const stepTypeModel = computed({
  get: () =>
    stepTypeOptions.value.find(o => o.id === props.modelValue.type) || null,
  set: option => option && emit('changeType', option.id),
});

const attributeModel = computed({
  get: () =>
    props.attributeOptions.find(o => o.id === props.modelValue.attribute_key) ||
    null,
  set: option => updateField('attribute_key', option?.id || ''),
});

const cannedResponseModelFor = field =>
  computed({
    get: () =>
      props.cannedResponseOptions.find(o => o.id === props.modelValue[field]) ||
      null,
    set: option => updateField(field, option?.id || ''),
  });

const promptCannedResponseModel = cannedResponseModelFor(
  'prompt_canned_response'
);
const retryCannedResponseModel = cannedResponseModelFor(
  'retry_canned_response'
);
const cannedResponseModel = cannedResponseModelFor('canned_response');
const foundCannedResponseModel = cannedResponseModelFor(
  'found_canned_response'
);
const notFoundCannedResponseModel = cannedResponseModelFor(
  'not_found_canned_response'
);

const extractCnpjModel = computed({
  get: () => props.modelValue.extract === 'cnpj',
  set: checked => updateField('extract', checked ? 'cnpj' : ''),
});
</script>

<template>
  <div
    class="flex flex-col gap-4 p-4 border rounded-lg border-n-weak bg-n-solid-1"
  >
    <div class="flex items-center justify-between gap-2">
      <div class="w-56">
        <SingleSelect
          v-model="stepTypeModel"
          :options="stepTypeOptions"
          disable-search
          disable-deselect
          :placeholder="t('INBOX_MGMT.BOT_FLOW.STEP_TYPES.SELECT_PLACEHOLDER')"
        />
      </div>
      <div class="flex items-center gap-1">
        <NextButton
          sm
          slate
          ghost
          icon="i-lucide-chevron-up"
          :disabled="isFirst"
          @click="$emit('moveUp')"
        />
        <NextButton
          sm
          slate
          ghost
          icon="i-lucide-chevron-down"
          :disabled="isLast"
          @click="$emit('moveDown')"
        />
        <NextButton
          sm
          ruby
          ghost
          icon="i-lucide-trash-2"
          @click="$emit('remove')"
        />
      </div>
    </div>

    <template v-if="modelValue.type === 'menu'">
      <WithLabel
        :label="t('INBOX_MGMT.BOT_FLOW.FIELDS.ATTRIBUTE')"
        name="attribute_key"
      >
        <SingleSelect
          v-model="attributeModel"
          :options="attributeOptions"
          :placeholder="t('INBOX_MGMT.BOT_FLOW.FIELDS.ATTRIBUTE_PLACEHOLDER')"
        />
      </WithLabel>
      <WithLabel
        :label="t('INBOX_MGMT.BOT_FLOW.FIELDS.PROMPT_CANNED_RESPONSE')"
        name="prompt_canned_response"
      >
        <SingleSelect
          v-model="promptCannedResponseModel"
          :options="cannedResponseOptions"
          :placeholder="
            t('INBOX_MGMT.BOT_FLOW.FIELDS.CANNED_RESPONSE_PLACEHOLDER')
          "
        />
      </WithLabel>
      <WithLabel
        :label="t('INBOX_MGMT.BOT_FLOW.FIELDS.RETRY_CANNED_RESPONSE')"
        name="retry_canned_response"
      >
        <SingleSelect
          v-model="retryCannedResponseModel"
          :options="cannedResponseOptions"
          :placeholder="
            t('INBOX_MGMT.BOT_FLOW.FIELDS.CANNED_RESPONSE_PLACEHOLDER')
          "
        />
      </WithLabel>
    </template>

    <template v-else-if="modelValue.type === 'ask_and_extract'">
      <WithLabel
        :label="t('INBOX_MGMT.BOT_FLOW.FIELDS.PROMPT_CANNED_RESPONSE')"
        name="prompt_canned_response"
      >
        <SingleSelect
          v-model="promptCannedResponseModel"
          :options="cannedResponseOptions"
          :placeholder="
            t('INBOX_MGMT.BOT_FLOW.FIELDS.CANNED_RESPONSE_PLACEHOLDER')
          "
        />
      </WithLabel>
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <Checkbox v-model="extractCnpjModel" />
        {{ t('INBOX_MGMT.BOT_FLOW.FIELDS.EXTRACT_CNPJ') }}
      </label>
      <template v-if="extractCnpjModel">
        <WithLabel
          :label="t('INBOX_MGMT.BOT_FLOW.FIELDS.FOUND_CANNED_RESPONSE')"
          name="found_canned_response"
        >
          <SingleSelect
            v-model="foundCannedResponseModel"
            :options="cannedResponseOptions"
            :placeholder="
              t('INBOX_MGMT.BOT_FLOW.FIELDS.CANNED_RESPONSE_PLACEHOLDER')
            "
          />
        </WithLabel>
        <WithLabel
          :label="t('INBOX_MGMT.BOT_FLOW.FIELDS.NOT_FOUND_CANNED_RESPONSE')"
          name="not_found_canned_response"
        >
          <SingleSelect
            v-model="notFoundCannedResponseModel"
            :options="cannedResponseOptions"
            :placeholder="
              t('INBOX_MGMT.BOT_FLOW.FIELDS.CANNED_RESPONSE_PLACEHOLDER')
            "
          />
        </WithLabel>
      </template>
    </template>

    <template v-else>
      <WithLabel
        :label="t('INBOX_MGMT.BOT_FLOW.FIELDS.CANNED_RESPONSE')"
        name="canned_response"
      >
        <SingleSelect
          v-model="cannedResponseModel"
          :options="cannedResponseOptions"
          :placeholder="
            t('INBOX_MGMT.BOT_FLOW.FIELDS.CANNED_RESPONSE_PLACEHOLDER')
          "
        />
      </WithLabel>
    </template>
  </div>
</template>
