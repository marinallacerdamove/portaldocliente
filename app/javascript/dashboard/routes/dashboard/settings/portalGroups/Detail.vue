<script setup>
// PATCH LOCAL (fork) - ficha de um Grupo de clientes (Configurações). Os dados
// moram no Portal. Uma lista só, com três abas:
// - "No grupo": empresas e contatos avulsos que estão no grupo;
// - "Todas as empresas": marcar a caixa põe a empresa inteira no grupo;
// - "Contatos avulsos": marcar a caixa põe só aquele contato.
// Clicar numa empresa abre os contatos dela logo abaixo, com a situação de
// cada um (recebe / inativo / sem telefone / sem cadastro no Chatwoot).
// Contato novo na empresa entra sozinho; contato inativado para de receber.
// Tudo é rascunho até o Salvar (um PATCH com nome, ativo e as listas
// COMPLETAS). Só administrador edita; agente vê só "No grupo", sem caixas, e o
// grupo automático "Todos os clientes ativos" nunca edita.
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { picoSearch } from '@chatwoot/pico-search';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { portalGroupsErrorMessage } from 'dashboard/composables/usePortalGroups';
import PortalGroupsAPI from 'dashboard/api/portalGroups';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import PortalGroupActiveBadge from 'dashboard/components-next/PortalGroups/PortalGroupActiveBadge.vue';
import PortalGroupCompanyRow from 'dashboard/components-next/PortalGroups/PortalGroupCompanyRow.vue';
import PortalGroupContactRow from 'dashboard/components-next/PortalGroups/PortalGroupContactRow.vue';

// Status de contato que conta como "recebe" (vem do Portal).
const RECEIVES = 'recebe';
const TABS = {
  MEMBERS: 'members',
  COMPANIES: 'companies',
  CONTACTS: 'contacts',
};

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

const activeTab = ref(TABS.MEMBERS);
const query = ref('');
const expandedIds = ref(new Set());

const canEdit = computed(() => isAdmin.value && !group.value?.automatic);

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

const memberEmpresas = computed(() =>
  draft.empresaIds.map(id => empresaLookup.value.get(id)).filter(Boolean)
);

const memberContatos = computed(() =>
  draft.partnerIds.map(id => contatoLookup.value.get(id)).filter(Boolean)
);

const empresaIdSet = computed(() => new Set(draft.empresaIds));
const partnerIdSet = computed(() => new Set(draft.partnerIds));

const search = (items, fields) => {
  const term = query.value.trim();
  return term ? picoSearch(items, term, fields) : items;
};

const EMPRESA_FIELDS = ['nome', 'cnpj'];
const CONTATO_FIELDS = ['name', 'phone', 'email', 'empresasText'];

const withEmpresasText = contatos =>
  contatos.map(contato => ({
    ...contato,
    empresasText: (contato.empresas || []).join(' '),
  }));

const visibleEmpresas = computed(() => {
  if (activeTab.value === TABS.CONTACTS) return [];
  const source =
    activeTab.value === TABS.MEMBERS
      ? memberEmpresas.value
      : options.value.empresas;
  return search(source, EMPRESA_FIELDS);
});

const visibleContatos = computed(() => {
  if (activeTab.value === TABS.COMPANIES) return [];
  const source =
    activeTab.value === TABS.MEMBERS
      ? memberContatos.value
      : options.value.contatos;
  return search(withEmpresasText(source), CONTATO_FIELDS);
});

const isEmpty = computed(
  () => !visibleEmpresas.value.length && !visibleContatos.value.length
);

const emptyMessage = computed(() => {
  if (query.value.trim()) return t('PORTAL_GROUPS.LIST.NO_MATCH');
  if (activeTab.value === TABS.MEMBERS) {
    return canEdit.value
      ? t('PORTAL_GROUPS.LIST.EMPTY_MEMBERS')
      : t('PORTAL_GROUPS.LIST.EMPTY_MEMBERS_READ_ONLY');
  }
  return t('PORTAL_GROUPS.LIST.EMPTY_OPTIONS');
});

const tabs = computed(() => [
  {
    key: TABS.MEMBERS,
    label: t('PORTAL_GROUPS.TABS.MEMBERS'),
    count: memberEmpresas.value.length + memberContatos.value.length,
  },
  {
    key: TABS.COMPANIES,
    label: t('PORTAL_GROUPS.TABS.COMPANIES'),
    count: options.value.empresas.length,
  },
  {
    key: TABS.CONTACTS,
    label: t('PORTAL_GROUPS.TABS.CONTACTS'),
    count: options.value.contatos.length,
  },
]);

const activeTabIndex = computed(() =>
  tabs.value.findIndex(tab => tab.key === activeTab.value)
);

const searchPlaceholder = computed(
  () =>
    ({
      [TABS.MEMBERS]: t('PORTAL_GROUPS.LIST.SEARCH_MEMBERS'),
      [TABS.COMPANIES]: t('PORTAL_GROUPS.LIST.SEARCH_COMPANIES'),
      [TABS.CONTACTS]: t('PORTAL_GROUPS.LIST.SEARCH_CONTACTS'),
    })[activeTab.value]
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

// Contatos que recebem: os que recebem nas empresas do grupo e os avulsos que
// recebem, sem repetir contato (pelo id). Mesma regra do Portal, então vale
// antes e depois de salvar. O grupo automático usa o número do Portal.
const recipientsCount = computed(() => {
  if (group.value?.automatic) return group.value.recipients_count ?? 0;
  const ids = new Set();
  memberEmpresas.value.forEach(empresa =>
    (empresa.contatos || [])
      .filter(contato => contato.status === RECEIVES)
      .forEach(contato => ids.add(contato.id))
  );
  memberContatos.value
    .filter(contato => contato.status === RECEIVES)
    .forEach(contato => ids.add(contato.id));
  return ids.size;
});

const contatoSubtitle = contato =>
  [
    partnerIdSet.value.has(contato.id) && activeTab.value === TABS.MEMBERS
      ? t('PORTAL_GROUPS.CONTACT.INDIVIDUAL')
      : '',
    ...(contato.empresas || []),
  ]
    .filter(Boolean)
    .join(' · ');

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
      portalGroupsErrorMessage(error) || t('PORTAL_GROUPS.LIST.OPTIONS_ERROR');
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

const selectTab = tab => {
  activeTab.value = tab.key;
  query.value = '';
};

const toggleId = (list, id) =>
  list.includes(id) ? list.filter(item => item !== id) : [...list, id];

const toggleEmpresa = id => {
  draft.empresaIds = toggleId(draft.empresaIds, id);
};

const toggleContato = id => {
  draft.partnerIds = toggleId(draft.partnerIds, id);
};

const toggleExpanded = id => {
  const next = new Set(expandedIds.value);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  expandedIds.value = next;
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
  id => {
    if (!id) return;
    activeTab.value = TABS.MEMBERS;
    query.value = '';
    expandedIds.value = new Set();
    fetchGroup(id);
  },
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

    <div v-else-if="group" class="flex flex-col w-full max-w-5xl gap-5 py-6">
      <header class="flex items-start justify-between gap-6">
        <div class="flex flex-col flex-1 min-w-0 gap-1">
          <div class="flex items-center min-w-0 gap-3">
            <input
              v-if="canEdit"
              v-model="draft.name"
              :aria-label="t('PORTAL_GROUPS.DETAIL.NAME_LABEL')"
              :placeholder="t('PORTAL_GROUPS.NAME_DIALOG.PLACEHOLDER')"
              :disabled="isSaving"
              class="w-full max-w-md px-2 py-1 -ms-2 text-xl font-semibold bg-transparent border border-transparent rounded-lg outline-none text-n-slate-12 hover:border-n-weak focus:border-n-brand"
            />
            <h1
              v-else
              class="my-0 text-xl font-semibold truncate text-n-slate-12"
            >
              {{ group.name }}
            </h1>
            <span
              v-if="group.automatic"
              class="px-2 py-0.5 text-xs rounded-md shrink-0 bg-n-blue-3 text-n-blue-11"
            >
              {{ t('PORTAL_GROUPS.AUTOMATIC') }}
            </span>
            <PortalGroupActiveBadge
              v-else-if="!canEdit"
              :active="group.active"
            />
          </div>
          <span class="text-sm text-n-slate-11">
            {{
              t(
                'PORTAL_GROUPS.DETAIL.RECIPIENTS',
                { count: recipientsCount },
                recipientsCount
              )
            }}
          </span>
        </div>

        <div v-if="canEdit" class="flex items-center gap-3 shrink-0 h-9">
          <label class="flex items-center gap-2 text-sm text-n-slate-11">
            <Switch v-model="draft.active" :disabled="isSaving" />
            {{ t('PORTAL_GROUPS.DETAIL.ACTIVE') }}
          </label>
          <Button
            v-if="isDirty"
            :label="t('PORTAL_GROUPS.DETAIL.DISCARD')"
            variant="ghost"
            color="slate"
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
      </header>

      <p v-if="saveError" class="mb-0 -mt-2 text-sm text-n-ruby-11">
        {{ saveError }}
      </p>

      <p
        v-if="group.automatic"
        class="px-4 py-3 mb-0 text-sm border rounded-xl border-n-weak bg-n-solid-1 text-n-slate-11"
      >
        {{ t('PORTAL_GROUPS.DETAIL.AUTOMATIC_HINT') }}
      </p>

      <section
        v-else
        class="flex flex-col overflow-hidden border rounded-xl border-n-weak bg-n-solid-1"
      >
        <div
          class="flex items-center justify-between gap-4 px-4 py-3 border-b border-n-weak"
        >
          <TabBar
            v-if="canEdit"
            :tabs="tabs"
            :initial-active-tab="activeTabIndex"
            @tab-changed="selectTab"
          />
          <span v-else class="text-sm text-n-slate-11">
            {{ t('PORTAL_GROUPS.DETAIL.READ_ONLY') }}
          </span>
          <div class="w-72 shrink-0">
            <Input
              v-model="query"
              type="search"
              size="sm"
              :placeholder="searchPlaceholder"
            />
          </div>
        </div>

        <div
          v-if="activeTab !== TABS.MEMBERS && isLoadingOptions"
          class="flex items-center gap-2 px-4 py-6 text-sm text-n-slate-11"
        >
          <Spinner :size="16" />
          {{ t('PORTAL_GROUPS.LIST.OPTIONS_LOADING') }}
        </div>

        <div
          v-else-if="activeTab !== TABS.MEMBERS && optionsError"
          class="flex flex-col items-start gap-2 px-4 py-6"
        >
          <p class="mb-0 text-sm text-n-ruby-11">{{ optionsError }}</p>
          <Button
            :label="t('PORTAL_GROUPS.RETRY')"
            variant="faded"
            color="slate"
            size="xs"
            @click="fetchOptions"
          />
        </div>

        <p v-else-if="isEmpty" class="px-4 py-6 mb-0 text-sm text-n-slate-11">
          {{ emptyMessage }}
        </p>

        <div v-else class="flex flex-col divide-y divide-n-weak">
          <PortalGroupCompanyRow
            v-for="empresa in visibleEmpresas"
            :key="`empresa-${empresa.id}`"
            :empresa="empresa"
            :checked="empresaIdSet.has(empresa.id)"
            :can-edit="canEdit && !isSaving"
            :expanded="expandedIds.has(empresa.id)"
            @toggle="toggleEmpresa"
            @expand="toggleExpanded"
          />
          <PortalGroupContactRow
            v-for="contato in visibleContatos"
            :key="`contato-${contato.id}`"
            :contato="contato"
            :subtitle="contatoSubtitle(contato)"
            :checked="partnerIdSet.has(contato.id)"
            :can-edit="canEdit && !isSaving"
            @toggle="toggleContato"
          />
        </div>
      </section>
    </div>
  </div>
</template>
