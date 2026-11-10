<script setup>
// PATCH LOCAL (fork) - ficha de um Grupo de clientes (Configurações). Os dados
// moram no Portal. Fluxo: dar nome, adicionar empresas (busca) e, na hora, ver
// os contatos de cada uma com a situação (recebe / inativo / sem telefone /
// sem cadastro no Chatwoot), e salvar. Contato novo na empresa entra sozinho;
// contato inativado vira "não recebe". Contatos avulsos ficam numa seção
// discreta no fim. Tudo é rascunho até o Salvar (um PATCH com nome, ativo e as
// listas COMPLETAS); o total "N contatos recebem" é estimado enquanto há
// mudança não salva. Só administrador edita; agente vê a mesma tela sem os
// controles, e o grupo automático "Todos os clientes ativos" nunca edita.
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { portalGroupsErrorMessage } from 'dashboard/composables/usePortalGroups';
import PortalGroupsAPI from 'dashboard/api/portalGroups';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import PortalGroupActiveBadge from 'dashboard/components-next/PortalGroups/PortalGroupActiveBadge.vue';
import PortalGroupCompanyBlock from 'dashboard/components-next/PortalGroups/PortalGroupCompanyBlock.vue';
import PortalGroupIndividualContacts from 'dashboard/components-next/PortalGroups/PortalGroupIndividualContacts.vue';
import PortalGroupMemberSearch from 'dashboard/components-next/PortalGroups/PortalGroupMemberSearch.vue';

// Status de contato de empresa que conta como "recebe" (vem do Portal).
const RECEIVES = 'recebe';

const { t } = useI18n();
const route = useRoute();
const { isAdmin } = useAdmin();

const group = ref(null);
const isLoading = ref(false);
const loadError = ref('');
const isSaving = ref(false);
const saveError = ref('');

// Rascunho: o que está na tela. O grupo salvo continua em `group`.
const draft = reactive({
  name: '',
  active: true,
  empresaIds: [],
  partnerIds: [],
});

const options = ref({ empresas: [], contatos: [] });
const isLoadingOptions = ref(false);
const optionsError = ref('');

const canEdit = computed(() => isAdmin.value && !group.value?.automatic);

const joinText = parts => parts.filter(Boolean).join(' · ');
const sameIds = (first, second) =>
  first.length === second.length &&
  [...first].sort().join() === [...second].sort().join();

// Empresas e contatos conhecidos: as opções do Portal, e por cima o que veio
// no grupo salvo (mais novo depois de salvar).
const empresaLookup = computed(() => {
  const lookup = new Map(options.value.empresas.map(item => [item.id, item]));
  (group.value?.empresas || []).forEach(item => lookup.set(item.id, item));
  return lookup;
});

const contatoLookup = computed(() => {
  const lookup = new Map(options.value.contatos.map(item => [item.id, item]));
  (group.value?.contatos || []).forEach(item => lookup.set(item.id, item));
  return lookup;
});

const empresaBlocks = computed(() =>
  draft.empresaIds.map(id => empresaLookup.value.get(id)).filter(Boolean)
);

const avulsos = computed(() =>
  draft.partnerIds.map(id => contatoLookup.value.get(id)).filter(Boolean)
);

const avulsoRows = computed(() =>
  avulsos.value.map(contato => ({
    id: contato.id,
    primary: contato.name,
    secondary: joinText([
      contato.phone || t('PORTAL_GROUPS.COMPANY.NO_PHONE'),
      (contato.empresas || []).join(', '),
    ]),
    active: contato.active,
  }))
);

const empresaCandidates = computed(() =>
  options.value.empresas.map(empresa => ({
    id: empresa.id,
    primary: empresa.nome,
    secondary: joinText([
      empresa.cnpj,
      t('PORTAL_GROUPS.COMPANY.RECEIVE_OF', {
        receive: empresa.recebem_count,
        total: empresa.contatos_count,
      }),
    ]),
  }))
);

const contatoCandidates = computed(() =>
  options.value.contatos.map(contato => ({
    id: contato.id,
    primary: contato.name,
    secondary: joinText([
      contato.email,
      contato.phone,
      (contato.empresas || []).join(', '),
    ]),
  }))
);

const listsChanged = computed(
  () =>
    !sameIds(
      draft.empresaIds,
      (group.value?.empresas || []).map(empresa => empresa.id)
    ) ||
    !sameIds(
      draft.partnerIds,
      (group.value?.contatos || []).map(contato => contato.id)
    )
);

const isDirty = computed(
  () =>
    listsChanged.value ||
    draft.name.trim() !== group.value?.name ||
    draft.active !== group.value?.active
);

const canSave = computed(
  () => canEdit.value && isDirty.value && !!draft.name.trim() && !isSaving.value
);

// Enquanto há mudança nas listas, soma os contatos que recebem das empresas
// escolhidas e os avulsos que recebem (status do Portal), sem repetir contato
// (pelo id). Sem mudança, vale o número que o Portal calculou.
const estimatedRecipients = computed(() => {
  const ids = new Set();
  empresaBlocks.value.forEach(empresa =>
    (empresa.contatos || [])
      .filter(contato => contato.status === RECEIVES)
      .forEach(contato => ids.add(contato.id))
  );
  avulsos.value
    .filter(contato => contato.status === RECEIVES)
    .forEach(contato => ids.add(contato.id));
  return ids.size;
});

const recipientsCount = computed(() =>
  listsChanged.value
    ? estimatedRecipients.value
    : (group.value?.recipients_count ?? 0)
);

const excludedText = computed(() => {
  const excluded = group.value?.excluded || {};
  return [
    [excluded.sem_telefone, t('PORTAL_GROUPS.DETAIL.EXCLUDED.NO_PHONE')],
    [
      excluded.sem_contato_no_chatwoot,
      t('PORTAL_GROUPS.DETAIL.EXCLUDED.NO_CHATWOOT_CONTACT'),
    ],
    [excluded.inativos, t('PORTAL_GROUPS.DETAIL.EXCLUDED.INACTIVE')],
  ]
    .filter(([count]) => count > 0)
    .map(([count, label]) => `${count} ${label}`)
    .join(' · ');
});

const resetDraft = () => {
  draft.name = group.value.name;
  draft.active = group.value.active;
  draft.empresaIds = (group.value.empresas || []).map(empresa => empresa.id);
  draft.partnerIds = (group.value.contatos || []).map(contato => contato.id);
  saveError.value = '';
};

const fetchOptions = async () => {
  isLoadingOptions.value = true;
  optionsError.value = '';
  try {
    ({ data: options.value } = await PortalGroupsAPI.memberOptions());
  } catch (error) {
    optionsError.value =
      portalGroupsErrorMessage(error) || t('PORTAL_GROUPS.SEARCH.ERROR');
  } finally {
    isLoadingOptions.value = false;
  }
};

const fetchGroup = async id => {
  isLoading.value = true;
  loadError.value = '';
  group.value = null;
  try {
    ({ data: group.value } = await PortalGroupsAPI.show(id));
  } catch (error) {
    loadError.value =
      portalGroupsErrorMessage(error) || t('PORTAL_GROUPS.LOAD_ERROR');
    return;
  } finally {
    isLoading.value = false;
  }
  resetDraft();
  if (canEdit.value) fetchOptions();
};

const addEmpresa = id => {
  draft.empresaIds = [id, ...draft.empresaIds];
};

const removeEmpresa = id => {
  draft.empresaIds = draft.empresaIds.filter(empresaId => empresaId !== id);
};

const addContato = id => {
  draft.partnerIds = [id, ...draft.partnerIds];
};

const removeContato = id => {
  draft.partnerIds = draft.partnerIds.filter(partnerId => partnerId !== id);
};

// Um único PATCH com tudo; o Portal devolve o detalhe já recalculado.
const save = async () => {
  if (!canSave.value) return;
  isSaving.value = true;
  saveError.value = '';
  try {
    ({ data: group.value } = await PortalGroupsAPI.update(group.value.id, {
      name: draft.name.trim(),
      active: draft.active,
      empresa_ids: draft.empresaIds,
      partner_ids: draft.partnerIds,
    }));
    resetDraft();
    useAlert(t('PORTAL_GROUPS.DETAIL.SAVE_SUCCESS'));
  } catch (error) {
    saveError.value =
      portalGroupsErrorMessage(error) || t('PORTAL_GROUPS.DETAIL.SAVE_ERROR');
    useAlert(saveError.value);
  } finally {
    isSaving.value = false;
  }
};

watch(
  () => route.params.groupId,
  id => id && fetchGroup(id),
  { immediate: true }
);
</script>

<template>
  <div class="flex flex-col w-full h-full !px-6 overflow-y-auto">
    <div v-if="isLoading" class="flex items-center gap-2 py-6 text-n-slate-11">
      <Spinner :size="16" />
      <span class="text-sm">{{ t('PORTAL_GROUPS.LOADING_GROUP') }}</span>
    </div>

    <div v-else-if="loadError" class="flex flex-col items-start gap-3 py-6">
      <p class="mb-0 text-sm text-n-ruby-11">{{ loadError }}</p>
      <Button
        :label="t('PORTAL_GROUPS.RETRY')"
        variant="faded"
        color="slate"
        size="sm"
        @click="fetchGroup(route.params.groupId)"
      />
    </div>

    <div v-else-if="group" class="flex flex-col w-full max-w-4xl gap-5 py-6">
      <p
        v-if="group.automatic"
        class="px-3 py-2 mb-0 text-sm border rounded-xl bg-n-blue-3 border-n-blue-4 text-n-blue-11"
      >
        {{ t('PORTAL_GROUPS.DETAIL.AUTOMATIC_HINT') }}
      </p>
      <p
        v-else-if="!isAdmin"
        class="px-3 py-2 mb-0 text-sm border rounded-xl bg-n-amber-3 border-n-amber-4 text-n-amber-11"
      >
        {{ t('PORTAL_GROUPS.DETAIL.READ_ONLY') }}
      </p>

      <section
        class="flex flex-col gap-4 p-4 border rounded-xl border-n-weak bg-n-solid-1"
      >
        <Input
          v-if="canEdit"
          id="portal-group-name"
          v-model="draft.name"
          :label="t('PORTAL_GROUPS.DETAIL.NAME_LABEL')"
          :placeholder="t('PORTAL_GROUPS.NAME_DIALOG.PLACEHOLDER')"
          :disabled="isSaving"
        />
        <div v-else class="flex items-center gap-3">
          <h1 class="my-0 text-xl font-semibold text-n-slate-12">
            {{ group.name }}
          </h1>
          <PortalGroupActiveBadge :active="group.active" />
        </div>

        <SettingsToggleSection
          v-if="canEdit"
          v-model="draft.active"
          :header="t('PORTAL_GROUPS.DETAIL.ACTIVE_LABEL')"
          :description="t('PORTAL_GROUPS.DETAIL.ACTIVE_HINT')"
        />

        <div class="flex flex-col gap-1">
          <span class="text-2xl font-semibold text-n-slate-12">
            {{
              t(
                'PORTAL_GROUPS.DETAIL.RECIPIENTS_TOTAL',
                { count: recipientsCount },
                recipientsCount
              )
            }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{
              listsChanged
                ? t('PORTAL_GROUPS.DETAIL.ESTIMATE_HINT')
                : t('PORTAL_GROUPS.DETAIL.RECIPIENTS_HINT')
            }}
          </span>
          <span
            v-if="!listsChanged && excludedText"
            class="text-xs text-n-slate-11"
          >
            {{ t('PORTAL_GROUPS.DETAIL.EXCLUDED_TITLE') }} {{ excludedText }}
          </span>
        </div>
      </section>

      <section v-if="!group.automatic" class="flex flex-col gap-3">
        <div class="flex flex-col gap-1">
          <h2 class="my-0 text-base font-semibold text-n-slate-12">
            {{
              t('PORTAL_GROUPS.COMPANY.TITLE', { count: empresaBlocks.length })
            }}
          </h2>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ t('PORTAL_GROUPS.COMPANY.HINT') }}
          </p>
        </div>

        <PortalGroupMemberSearch
          v-if="canEdit"
          :candidates="empresaCandidates"
          :excluded-ids="draft.empresaIds"
          :placeholder="t('PORTAL_GROUPS.COMPANY.SEARCH')"
          :is-loading="isLoadingOptions"
          :error="optionsError"
          :disabled="isSaving"
          @add="addEmpresa"
          @retry="fetchOptions"
        />

        <PortalGroupCompanyBlock
          v-for="empresa in empresaBlocks"
          :key="empresa.id"
          :empresa="empresa"
          :can-edit="canEdit && !isSaving"
          @remove="removeEmpresa"
        />
        <p v-if="!empresaBlocks.length" class="mb-0 text-sm text-n-slate-11">
          {{ t('PORTAL_GROUPS.COMPANY.EMPTY') }}
        </p>
      </section>

      <PortalGroupIndividualContacts
        v-if="!group.automatic && (canEdit || avulsoRows.length)"
        :rows="avulsoRows"
        :candidates="contatoCandidates"
        :can-edit="canEdit && !isSaving"
        :is-loading-candidates="isLoadingOptions"
        :candidates-error="optionsError"
        @add="addContato"
        @remove="removeContato"
        @retry="fetchOptions"
      />

      <footer
        v-if="canEdit"
        class="flex flex-col gap-2 pt-4 border-t border-n-weak"
      >
        <p v-if="saveError" class="mb-0 text-sm text-n-ruby-11">
          {{ saveError }}
        </p>
        <div class="flex items-center justify-end gap-2">
          <Button
            v-if="isDirty"
            :label="t('PORTAL_GROUPS.DETAIL.DISCARD')"
            ghost
            slate
            size="sm"
            :disabled="isSaving"
            @click="resetDraft"
          />
          <Button
            :label="t('PORTAL_GROUPS.DETAIL.SAVE')"
            size="sm"
            :is-loading="isSaving"
            :disabled="!canSave"
            @click="save"
          />
        </div>
      </footer>
    </div>
  </div>
</template>
