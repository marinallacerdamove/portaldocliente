<script setup>
// Tabela de bases do Update Server (Albatross) com formulário de adicionar e
// editar. Sem exclusão: a base sai de uso desmarcando Ativo.
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';

const props = defineProps({
  bases: { type: Array, default: () => [] },
  isSaving: { type: Boolean, default: false },
  save: { type: Function, required: true },
});

const { t } = useI18n();

const FIELDS = [
  { key: 'albatross_id', type: 'number', required: true },
  { key: 'display_code', type: 'number' },
  { key: 'razao_social' },
  { key: 'display_name' },
  { key: 'database_name' },
  { key: 'link' },
  { key: 'documento' },
];

const emptyDraft = () => ({
  albatross_id: '',
  display_code: '',
  razao_social: '',
  display_name: '',
  database_name: '',
  link: '',
  documento: '',
  active: true,
});

const editingId = ref(null); // 'new' ou o id da base
const draft = ref(emptyDraft());

const startNew = () => {
  draft.value = emptyDraft();
  editingId.value = 'new';
};

const startEdit = base => {
  draft.value = { ...emptyDraft(), ...base };
  editingId.value = base.id;
};

const cancel = () => {
  editingId.value = null;
};

const submit = async () => {
  const attributes = Object.fromEntries(
    [...FIELDS.map(field => field.key), 'active'].map(key => [
      key,
      draft.value[key],
    ])
  );
  const baseId = editingId.value === 'new' ? null : editingId.value;
  if (await props.save(baseId, attributes)) editingId.value = null;
};

const isHttpLink = link => /^https?:\/\//i.test(link || '');
</script>

<template>
  <InfoCard
    :title="t('COMPANIES.DETAIL.UPDATE_SERVER.BASES.TITLE')"
    icon="i-lucide-database"
  >
    <template #actions>
      <Button
        v-if="editingId === null"
        :label="t('COMPANIES.DETAIL.UPDATE_SERVER.BASES.ADD')"
        icon="i-lucide-plus"
        ghost
        slate
        xs
        @click="startNew"
      />
      <span v-else />
    </template>

    <div v-if="editingId !== null" class="flex flex-col gap-3 mb-4">
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Input
          v-for="field in FIELDS"
          :key="field.key"
          v-model="draft[field.key]"
          :type="field.type || 'text'"
          :label="t(`COMPANIES.DETAIL.UPDATE_SERVER.BASES.FIELDS.${field.key}`)"
          :disabled="isSaving"
          custom-input-class="h-8 !pt-1 !pb-1"
        />
      </div>
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <Checkbox v-model="draft.active" :disabled="isSaving" />
        {{ t('COMPANIES.DETAIL.UPDATE_SERVER.ACTIVE') }}
      </label>
      <div class="flex items-center justify-end gap-2">
        <Button
          :label="t('COMPANIES.DETAIL.UPDATE_SERVER.CANCEL')"
          ghost
          slate
          xs
          @click="cancel"
        />
        <Button
          :label="
            isSaving
              ? t('COMPANIES.DETAIL.UPDATE_SERVER.SAVING')
              : t('COMPANIES.DETAIL.UPDATE_SERVER.SAVE')
          "
          :disabled="isSaving || !draft.albatross_id"
          xs
          @click="submit"
        />
      </div>
    </div>

    <p v-if="!bases.length" class="my-0 text-sm text-n-slate-11">
      {{ t('COMPANIES.DETAIL.UPDATE_SERVER.BASES.EMPTY') }}
    </p>
    <div v-else class="overflow-x-auto">
      <table class="w-full text-sm text-left">
        <thead>
          <tr class="text-xs uppercase text-n-slate-10">
            <th
              v-for="field in FIELDS"
              :key="field.key"
              class="py-2 pr-3 font-semibold whitespace-nowrap"
            >
              {{
                t(`COMPANIES.DETAIL.UPDATE_SERVER.BASES.FIELDS.${field.key}`)
              }}
            </th>
            <th class="py-2 pr-3 font-semibold">
              {{ t('COMPANIES.DETAIL.UPDATE_SERVER.ACTIVE') }}
            </th>
            <th class="py-2" />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="base in bases"
            :key="base.id"
            class="border-t border-n-weak text-n-slate-12"
            :class="{ 'opacity-60': !base.active }"
          >
            <td v-for="field in FIELDS" :key="field.key" class="py-2 pr-3">
              <a
                v-if="field.key === 'link' && isHttpLink(base.link)"
                :href="base.link"
                target="_blank"
                rel="noopener noreferrer"
                class="text-n-blue-11 hover:underline"
              >
                {{ base.link }}
              </a>
              <span v-else>{{ base[field.key] ?? '' }}</span>
            </td>
            <td class="py-2 pr-3">
              {{
                base.active
                  ? t('COMPANIES.DETAIL.UPDATE_SERVER.YES')
                  : t('COMPANIES.DETAIL.UPDATE_SERVER.NO')
              }}
            </td>
            <td class="py-2 text-right">
              <Button
                v-tooltip.top="t('COMPANIES.DETAIL.UPDATE_SERVER.EDIT')"
                icon="i-lucide-pencil"
                ghost
                slate
                xs
                :disabled="editingId !== null"
                @click="startEdit(base)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </InfoCard>
</template>
