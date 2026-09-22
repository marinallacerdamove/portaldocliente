<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import InspectorSection from '../components/InspectorSection.vue';
import VariableInput from '../components/variables/VariableInput.vue';
import VariableTextArea from '../components/variables/VariableTextArea.vue';

defineProps({
  entries: { type: Array, default: () => [] },
  recentIds: { type: Array, default: () => [] },
  recordUsage: { type: Function, default: () => {} },
});

const modelValue = defineModel({ type: Object, required: true });
const { t } = useI18n();

const methodOptions = [
  { id: 'get', name: 'GET' },
  { id: 'post', name: 'POST' },
];

const methodModel = computed({
  get: () =>
    methodOptions.find(o => o.id === modelValue.value.method) ||
    methodOptions[0],
  set: option => {
    modelValue.value.method = option?.id || 'get';
  },
});

const addHeader = () => {
  modelValue.value.headers = [
    ...(modelValue.value.headers || []),
    { key: '', value: '' },
  ];
};
const removeHeader = index => {
  modelValue.value.headers = modelValue.value.headers.filter(
    (_, i) => i !== index
  );
};

const successCheckEnabled = computed({
  get: () => !!modelValue.value.success_check,
  set: enabled => {
    modelValue.value.success_check = enabled ? { field: '', equals: '' } : null;
  },
});

const addMapping = () => {
  modelValue.value.response_mappings = [
    ...(modelValue.value.response_mappings || []),
    { json_path: '', variable_name: '' },
  ];
};
const removeMapping = index => {
  modelValue.value.response_mappings =
    modelValue.value.response_mappings.filter((_, i) => i !== index);
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <p class="text-xs text-n-slate-10 bg-n-slate-2 rounded-lg p-2">
      {{ t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.INTRO_HELP') }}
    </p>

    <InspectorSection :title="t('BOT_FLOW.EDITOR.PANEL.SECTIONS.REQUEST')">
      <WithLabel
        :label="t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.METHOD_LABEL')"
        name="method"
      >
        <SingleSelect
          v-model="methodModel"
          :options="methodOptions"
          disable-search
          disable-deselect
        />
      </WithLabel>

      <WithLabel
        :label="t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.URL_LABEL')"
        name="url"
        required
      >
        <VariableInput
          v-model="modelValue.url"
          :entries="entries"
          :recent-ids="recentIds"
          :record-usage="recordUsage"
          :placeholder="t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.URL_PLACEHOLDER')"
        />
      </WithLabel>

      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-11">{{
          t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.HEADERS_LABEL')
        }}</span>
        <div
          v-for="(header, index) in modelValue.headers || []"
          :key="index"
          class="flex items-center gap-2"
        >
          <NextInput
            v-model="header.key"
            class="flex-1"
            :placeholder="
              t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.HEADER_KEY_PLACEHOLDER')
            "
          />
          <NextInput
            v-model="header.value"
            class="flex-1"
            :placeholder="
              t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.HEADER_VALUE_PLACEHOLDER')
            "
          />
          <NextButton
            icon="i-lucide-trash-2"
            slate
            ghost
            sm
            @click="removeHeader(index)"
          />
        </div>
        <NextButton
          sm
          slate
          faded
          icon="i-lucide-plus"
          :label="t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.ADD_HEADER')"
          @click="addHeader"
        />
      </div>

      <WithLabel
        v-if="modelValue.method === 'post'"
        :label="t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.BODY_LABEL')"
        name="body_template"
      >
        <VariableTextArea
          v-model="modelValue.body_template"
          monospace
          :rows="3"
          :entries="entries"
          :recent-ids="recentIds"
          :record-usage="recordUsage"
          :placeholder="t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.BODY_PLACEHOLDER')"
        />
      </WithLabel>
    </InspectorSection>

    <InspectorSection :title="t('BOT_FLOW.EDITOR.PANEL.SECTIONS.RESPONSE')">
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <Checkbox v-model="successCheckEnabled" />
        {{ t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.SUCCESS_CHECK_LABEL') }}
      </label>
      <div v-if="modelValue.success_check" class="flex items-center gap-2">
        <NextInput
          v-model="modelValue.success_check.field"
          class="flex-1"
          :placeholder="
            t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.SUCCESS_CHECK_FIELD_PLACEHOLDER')
          "
        />
        <NextInput
          v-model="modelValue.success_check.equals"
          class="flex-1"
          :placeholder="
            t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.SUCCESS_CHECK_VALUE_PLACEHOLDER')
          "
        />
      </div>

      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-11">
          {{ t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.RESPONSE_MAPPINGS_LABEL') }}
        </span>
        <div
          v-for="(mapping, index) in modelValue.response_mappings || []"
          :key="index"
          class="flex items-center gap-2"
        >
          <NextInput
            v-model="mapping.json_path"
            class="flex-1"
            :placeholder="
              t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.JSON_PATH_PLACEHOLDER')
            "
          />
          <NextInput
            v-model="mapping.variable_name"
            class="flex-1"
            :placeholder="
              t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.VARIABLE_NAME_PLACEHOLDER')
            "
          />
          <NextButton
            icon="i-lucide-trash-2"
            slate
            ghost
            sm
            @click="removeMapping(index)"
          />
        </div>
        <NextButton
          sm
          slate
          faded
          icon="i-lucide-plus"
          :label="t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.ADD_MAPPING')"
          @click="addMapping"
        />
      </div>
    </InspectorSection>
  </div>
</template>
