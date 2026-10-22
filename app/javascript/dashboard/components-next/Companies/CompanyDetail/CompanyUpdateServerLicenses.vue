<script setup>
// Licenças do Albatross da empresa: uma linha por usuário com os módulos dele.
// Sem exclusão: a licença sai de uso desmarcando Ativa (e deixa de contar nos
// totais). O total por módulo é somado no Portal.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';

const props = defineProps({
  licenses: { type: Array, default: () => [] },
  modules: { type: Array, default: () => [] },
  isSaving: { type: Boolean, default: false },
  save: { type: Function, required: true },
});

const { t } = useI18n();

const emptyDraft = () => ({
  user_name: '',
  code: '',
  license_type: '',
  active: true,
  license_module_ids: [],
});

const editingId = ref(null); // 'new' ou o id da licença
const draft = ref(emptyDraft());

// Módulo inativo só aparece se a licença em edição ainda o tem.
const selectableModules = computed(() =>
  props.modules.filter(
    mod => mod.active || draft.value.license_module_ids.includes(mod.id)
  )
);

const startNew = () => {
  draft.value = emptyDraft();
  editingId.value = 'new';
};

const startEdit = license => {
  draft.value = {
    ...emptyDraft(),
    ...license,
    license_module_ids: [...license.license_module_ids],
  };
  editingId.value = license.id;
};

const cancel = () => {
  editingId.value = null;
};

const isModuleChecked = id => draft.value.license_module_ids.includes(id);

const toggleModule = (id, checked) => {
  const others = draft.value.license_module_ids.filter(item => item !== id);
  draft.value.license_module_ids = checked ? [...others, id] : others;
};

const submit = async () => {
  const { user_name, code, license_type, active, license_module_ids } =
    draft.value;
  const licenseId = editingId.value === 'new' ? null : editingId.value;
  const saved = await props.save(licenseId, {
    user_name,
    code,
    license_type,
    active,
    license_module_ids,
  });
  if (saved) editingId.value = null;
};
</script>

<template>
  <InfoCard
    :title="t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.TITLE')"
    icon="i-lucide-key-round"
  >
    <template #actions>
      <Button
        v-if="editingId === null"
        :label="t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.ADD')"
        icon="i-lucide-plus"
        ghost
        slate
        xs
        @click="startNew"
      />
      <span v-else />
    </template>

    <div v-if="editingId !== null" class="flex flex-col gap-3 mb-4">
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <Input
          v-model="draft.user_name"
          :label="t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.FIELDS.user_name')"
          :disabled="isSaving"
          custom-input-class="h-8 !pt-1 !pb-1"
        />
        <Input
          v-model="draft.code"
          :label="t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.FIELDS.code')"
          :disabled="isSaving"
          custom-input-class="h-8 !pt-1 !pb-1"
        />
        <Input
          v-model="draft.license_type"
          :label="
            t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.FIELDS.license_type')
          "
          :disabled="isSaving"
          custom-input-class="h-8 !pt-1 !pb-1"
        />
      </div>
      <div class="flex flex-col gap-2">
        <span class="text-heading-3 text-n-slate-12">
          {{ t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.MODULES') }}
        </span>
        <div class="flex flex-wrap gap-x-4 gap-y-2">
          <label
            v-for="mod in selectableModules"
            :key="mod.id"
            class="flex items-center gap-2 text-sm text-n-slate-12"
          >
            <Checkbox
              :model-value="isModuleChecked(mod.id)"
              :disabled="isSaving"
              @update:model-value="toggleModule(mod.id, $event)"
            />
            <span :title="mod.name">{{ mod.code }}</span>
          </label>
        </div>
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
          :disabled="
            isSaving ||
            !draft.user_name.trim() ||
            !draft.license_module_ids.length
          "
          xs
          @click="submit"
        />
      </div>
    </div>

    <p v-if="!licenses.length" class="my-0 text-sm text-n-slate-11">
      {{ t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.EMPTY') }}
    </p>
    <div v-else class="overflow-x-auto">
      <table class="w-full text-sm text-left">
        <thead>
          <tr class="text-xs uppercase text-n-slate-10">
            <th class="py-2 pr-3 font-semibold">
              {{
                t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.FIELDS.user_name')
              }}
            </th>
            <th class="py-2 pr-3 font-semibold">
              {{ t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.FIELDS.code') }}
            </th>
            <th class="py-2 pr-3 font-semibold">
              {{
                t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.FIELDS.license_type')
              }}
            </th>
            <th class="py-2 pr-3 font-semibold">
              {{ t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.MODULES') }}
            </th>
            <th class="py-2 pr-3 font-semibold">
              {{ t('COMPANIES.DETAIL.UPDATE_SERVER.ACTIVE') }}
            </th>
            <th class="py-2" />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="license in licenses"
            :key="license.id"
            class="border-t border-n-weak text-n-slate-12"
            :class="{ 'opacity-60': !license.active }"
          >
            <td class="py-2 pr-3">{{ license.user_name }}</td>
            <td class="py-2 pr-3">{{ license.code }}</td>
            <td class="py-2 pr-3">{{ license.license_type }}</td>
            <td class="py-2 pr-3 font-mono text-xs">
              {{ license.combination }}
            </td>
            <td class="py-2 pr-3">
              {{
                license.active
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
                @click="startEdit(license)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </InfoCard>
</template>
