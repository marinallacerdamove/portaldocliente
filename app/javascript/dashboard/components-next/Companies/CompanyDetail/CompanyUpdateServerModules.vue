<script setup>
// Módulos de licença (STK, SUP...): cadastro único, igual ao modal "Módulos"
// do Portal. Cadastrar, renomear, ligar/desligar e reordenar; nunca excluir
// (módulo que saiu de uso é inativado e continua nas licenças que já o usam).
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import UpdateServerEmpty from './UpdateServerEmpty.vue';
import UpdateServerModuleChip from './UpdateServerModuleChip.vue';
import UpdateServerStatusSwitch from './UpdateServerStatusSwitch.vue';

const props = defineProps({
  modules: { type: Array, default: () => [] },
  isBusy: { type: Boolean, default: false },
  // (moduleId, attributes) e (ids) => Promise<{ ok, message }>, sem alerta
  // próprio: o erro do Portal aparece aqui dentro.
  saveModule: { type: Function, required: true },
  reorderModules: { type: Function, required: true },
});
const emit = defineEmits(['close']);

const { t } = useI18n();
const i18nKey = suffix =>
  `COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.MODULES_PANEL.${suffix}`;

const error = ref('');
const draft = ref({ code: '', name: '' });
const renaming = ref({});

const apply = async request => {
  const result = await request();
  error.value = result.ok ? '' : result.message;
  return result.ok;
};

const add = async () => {
  const added = await apply(() =>
    props.saveModule(null, { code: draft.value.code, name: draft.value.name })
  );
  if (added) draft.value = { code: '', name: '' };
};

const toggle = (mod, active) =>
  apply(() => props.saveModule(mod.id, { active }));

const rename = async mod => {
  const name = renaming.value[mod.id];
  delete renaming.value[mod.id];
  if (name === undefined || name === mod.name) return;
  await apply(() => props.saveModule(mod.id, { name }));
};

const move = (index, step) => {
  const ids = props.modules.map(mod => mod.id);
  ids.splice(index + step, 0, ids.splice(index, 1)[0]);
  return apply(() => props.reorderModules(ids));
};
</script>

<template>
  <div
    class="flex flex-col gap-4 p-4 mb-4 border rounded-lg border-n-weak bg-n-alpha-1"
  >
    <div>
      <p class="my-0 text-sm font-medium text-n-slate-12">
        {{ t(i18nKey('TITLE')) }}
      </p>
      <p class="mt-1 mb-0 text-xs text-n-slate-11">
        {{ t(i18nKey('DESCRIPTION')) }}
      </p>
    </div>

    <p
      v-if="error"
      class="p-3 my-0 text-xs border rounded-lg border-n-ruby-6 bg-n-ruby-2 text-n-ruby-11"
      role="alert"
    >
      {{ error }}
    </p>

    <UpdateServerEmpty
      v-if="!modules.length"
      icon="i-lucide-layout-list"
      :title="t(i18nKey('EMPTY'))"
    />
    <ul v-else class="flex flex-col gap-1.5 p-0 m-0 list-none">
      <li
        v-for="(mod, index) in modules"
        :key="mod.id"
        class="flex items-center gap-2 px-3 py-2 border rounded-lg border-n-weak bg-n-solid-1"
      >
        <div class="flex flex-col shrink-0">
          <Button
            :aria-label="t(i18nKey('MOVE_UP'))"
            icon="i-lucide-chevron-up"
            ghost
            slate
            xs
            :disabled="isBusy || index === 0"
            @click="move(index, -1)"
          />
          <Button
            :aria-label="t(i18nKey('MOVE_DOWN'))"
            icon="i-lucide-chevron-down"
            ghost
            slate
            xs
            :disabled="isBusy || index === modules.length - 1"
            @click="move(index, 1)"
          />
        </div>
        <div class="w-20 shrink-0">
          <UpdateServerModuleChip
            :code="mod.code"
            :name="mod.name"
            :inactive="!mod.active"
          />
        </div>
        <div class="flex-1 min-w-0">
          <Input
            :model-value="renaming[mod.id] ?? mod.name"
            size="sm"
            :disabled="isBusy"
            :placeholder="t(i18nKey('NAME_PLACEHOLDER'))"
            custom-input-class="h-8 !pt-1 !pb-1"
            @update:model-value="renaming[mod.id] = $event"
            @blur="rename(mod)"
            @enter="rename(mod)"
          />
        </div>
        <UpdateServerStatusSwitch
          :active="mod.active"
          :busy="isBusy"
          :label="t(i18nKey('TOGGLE'), { code: mod.code })"
          @toggle="toggle(mod, $event)"
        />
      </li>
    </ul>

    <div class="flex items-end gap-2 pt-3 border-t border-n-weak">
      <div class="w-28">
        <Input
          v-model="draft.code"
          :label="
            t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.FIELDS.module_code')
          "
          :placeholder="t(i18nKey('CODE_PLACEHOLDER'))"
          :disabled="isBusy"
          custom-input-class="h-8 !pt-1 !pb-1"
        />
      </div>
      <div class="flex-1 min-w-0">
        <Input
          v-model="draft.name"
          :label="
            t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.FIELDS.module_name')
          "
          :placeholder="t(i18nKey('NAME_PLACEHOLDER'))"
          :disabled="isBusy"
          custom-input-class="h-8 !pt-1 !pb-1"
        />
      </div>
      <Button
        :label="t(i18nKey('ADD'))"
        icon="i-lucide-plus"
        xs
        :disabled="isBusy || !draft.code.trim()"
        @click="add"
      />
    </div>

    <div class="flex justify-end">
      <Button
        :label="t('COMPANIES.DETAIL.UPDATE_SERVER.CLOSE')"
        ghost
        slate
        xs
        @click="emit('close')"
      />
    </div>
  </div>
</template>
