<script setup>
// "Adicionar vários usuários": um usuário por linha, com o mesmo código, tipo
// e módulos pra todos. Cria uma licença por usuário, uma de cada vez, pelo
// mesmo repasse do formulário simples; quem falhar fica na caixa pra tentar de
// novo e quem deu certo não se perde.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import UpdateServerModuleChip from './UpdateServerModuleChip.vue';
import { hasActiveUser, parseBulkUsers } from './updateServerHelpers';

const props = defineProps({
  modules: { type: Array, default: () => [] },
  licenses: { type: Array, default: () => [] },
  // (licenseId, attributes) => Promise<{ ok, message }>, sem alerta próprio.
  saveEach: { type: Function, required: true },
});
const emit = defineEmits(['close']);

const { t } = useI18n();
const i18nKey = suffix =>
  `COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.BULK.${suffix}`;

const usersText = ref('');
const code = ref('');
const licenseType = ref('');
const moduleIds = ref([]);
const running = ref(false);
const progress = ref({ done: 0, total: 0 });
const created = ref(0);
const failures = ref([]);

const parsed = computed(() => parseBulkUsers(usersText.value));
const activeModules = computed(() => props.modules.filter(mod => mod.active));
const alreadyActive = computed(
  () =>
    parsed.value.users.filter(user => hasActiveUser(props.licenses, user))
      .length
);
const canSubmit = computed(
  () => !running.value && parsed.value.users.length && moduleIds.value.length
);

const toggleModule = (id, checked) => {
  const others = moduleIds.value.filter(item => item !== id);
  moduleIds.value = checked ? [...others, id] : others;
};

const submit = async () => {
  const users = [...parsed.value.users];
  running.value = true;
  created.value = 0;
  failures.value = [];
  progress.value = { done: 0, total: users.length };
  // Uma de cada vez (o Portal numera e valida em sequência): encadeia as promessas.
  await users.reduce(
    (chain, user) =>
      chain.then(async () => {
        const result = await props.saveEach(null, {
          user_name: user,
          code: code.value,
          license_type: licenseType.value,
          active: true,
          license_module_ids: moduleIds.value,
        });
        if (result.ok) created.value += 1;
        else failures.value.push({ user, message: result.message });
        progress.value.done += 1;
      }),
    Promise.resolve()
  );
  // Só os que falharam voltam pra caixa, prontos pra nova tentativa.
  usersText.value = failures.value.map(item => item.user).join('\n');
  running.value = false;
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

    <TextArea
      v-model="usersText"
      :label="t(i18nKey('USERS'))"
      :placeholder="t(i18nKey('USERS_PLACEHOLDER'))"
      :disabled="running"
      :max-length="5000"
      min-height="8rem"
      resize
    />

    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <Input
        v-model="code"
        :label="t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.FIELDS.code')"
        :placeholder="
          t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.PLACEHOLDERS.code')
        "
        :disabled="running"
        custom-input-class="h-8 !pt-1 !pb-1"
      />
      <Input
        v-model="licenseType"
        :label="
          t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.FIELDS.license_type')
        "
        :placeholder="
          t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.PLACEHOLDERS.license_type')
        "
        :disabled="running"
        custom-input-class="h-8 !pt-1 !pb-1"
      />
    </div>

    <fieldset class="flex flex-col gap-2 p-0 m-0 border-0">
      <legend class="p-0 mb-2 text-xs font-semibold uppercase text-n-slate-10">
        {{ t('COMPANIES.DETAIL.UPDATE_SERVER.LICENSES.MODULES') }}
      </legend>
      <div class="flex flex-wrap gap-x-4 gap-y-2">
        <label
          v-for="mod in activeModules"
          :key="mod.id"
          class="flex items-center gap-2 text-sm text-n-slate-12"
        >
          <Checkbox
            :model-value="moduleIds.includes(mod.id)"
            :disabled="running"
            @update:model-value="toggleModule(mod.id, $event)"
          />
          <UpdateServerModuleChip :code="mod.code" :name="mod.name" />
        </label>
      </div>
    </fieldset>

    <div class="flex flex-col gap-1 text-xs text-n-slate-11" aria-live="polite">
      <p v-if="parsed.users.length" class="my-0">
        {{
          t(
            i18nKey('PREVIEW'),
            { count: parsed.users.length },
            parsed.users.length
          )
        }}
      </p>
      <p v-if="parsed.ignored" class="my-0">
        {{ t(i18nKey('IGNORED'), { count: parsed.ignored }, parsed.ignored) }}
      </p>
      <p v-if="alreadyActive" class="my-0 text-n-amber-11">
        {{ t(i18nKey('EXISTING'), { count: alreadyActive }, alreadyActive) }}
      </p>
      <p v-if="running" class="my-0 text-n-slate-12">
        {{ t(i18nKey('PROGRESS'), progress) }}
      </p>
      <p v-else-if="progress.total" class="my-0 text-n-teal-11">
        {{ t(i18nKey('DONE'), { count: created }, created) }}
      </p>
    </div>

    <div
      v-if="failures.length"
      class="flex flex-col gap-1 p-3 text-xs border rounded-lg border-n-ruby-6 bg-n-ruby-2 text-n-ruby-11"
      role="alert"
    >
      <p class="my-0 font-medium">{{ t(i18nKey('FAILED_TITLE')) }}</p>
      <p v-for="item in failures" :key="item.user" class="my-0">
        {{ `${item.user}: ${item.message}` }}
      </p>
    </div>

    <div class="flex items-center justify-end gap-2">
      <Button
        :label="t('COMPANIES.DETAIL.UPDATE_SERVER.CLOSE')"
        ghost
        slate
        xs
        :disabled="running"
        @click="emit('close')"
      />
      <Button
        :label="t(i18nKey('SUBMIT'))"
        icon="i-lucide-users"
        xs
        :disabled="!canSubmit"
        @click="submit"
      />
    </div>
  </div>
</template>
