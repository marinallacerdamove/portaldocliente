<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { dynamicTime } from 'shared/helpers/timeHelper';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { useCompaniesStore } from 'dashboard/stores/companies';
import InfoCard from 'dashboard/components-next/InfoCard/InfoCard.vue';
import InfoCardFields from 'dashboard/components-next/InfoCard/InfoCardFields.vue';
import {
  SEGMENTOS,
  CLASSIFICACOES,
  SERVIDOR_TIPOS,
  TIPOS_ACESSO,
  CONTRATO_STATUSES,
  ALBATROSS_MODULOS,
  TIPO_EMPRESA_OPTIONS,
  ESTADOS_BR,
  REGIME_TRIBUTARIO,
} from 'dashboard/constants/portalCompanyFields';

const props = defineProps({
  company: { type: Object, default: () => ({}) },
  isLoading: { type: Boolean, default: false },
});

const { t, locale } = useI18n();
const companiesStore = useCompaniesStore();
const { shouldShow } = usePolicy();

// Financeiro fica atrás de um perfil personalizado (Configurações > Perfis de
// acesso > "Financeiro") - permissão de verdade agora ('financeiro_manage',
// ver enterprise/app/models/custom_role.rb no backend), com bloqueio também
// no backend (CompanyPolicy#financeiro_manage?, companies_controller.rb) -
// isso aqui só controla a exibição da aba, o dado em si já vem filtrado da
// API pra quem não tem a permissão.
const FINANCEIRO_PERMISSION = 'financeiro_manage';
// Administrador sempre vê Financeiro também - a permissão do perfil
// personalizado (custom_role.permissions) substitui ['administrator'] por
// completo pra quem tem role, não soma; sem checar 'administrator' aqui,
// nem o admin da conta veria a aba.
const canViewFinanceiro = computed(() =>
  shouldShow(null, [FINANCEIRO_PERMISSION, 'administrator'])
);

const CARD_TABS = computed(() =>
  [
    { key: 'dados', label: 'Visão geral' },
    canViewFinanceiro.value && { key: 'financeiro', label: 'Contrato' },
    { key: 'contabilidade', label: 'Contabilidade' },
  ].filter(Boolean)
);
const activeTabKey = ref('dados');
const activeTabIndex = computed(() =>
  Math.max(
    CARD_TABS.value.findIndex(tab => tab.key === activeTabKey.value),
    0
  )
);
const handleTabChanged = tab => {
  activeTabKey.value = tab.key;
};

// Campos do Portal do Cliente que não têm um lugar nativo no Chatwoot -
// ficam aqui como custom attributes da empresa (company_attribute), editados
// junto com Nome/Domínio/Descrição no mesmo formulário e no mesmo "Salvar".
// A ordem dos campos (leitura e edição) espelha a ficha de Empresa do Portal
// (frontend/src/views/admin/EmpresaOverviewView.vue) - mexeu lá, mexe aqui.
// nome_fantasia não entra aqui de propósito - é a mesma coisa que o campo
// nativo "Nome" logo acima, editar os dois separados só divergiria os dois.
// cnpj e cep também ficam fora - têm busca (Receita/ViaCEP) e são
// renderizados à mão, não pelo grid genérico.
const FIELD_GROUPS = [
  {
    titleKey: 'DADOS_EMPRESA',
    tab: 'dados',
    fields: [
      { key: 'segmento', type: 'select', options: SEGMENTOS },
      { key: 'classificacao', type: 'select', options: CLASSIFICACOES },
      { key: 'tipo_empresa', type: 'select', options: TIPO_EMPRESA_OPTIONS },
    ],
  },
  {
    titleKey: 'ENDERECO',
    tab: 'dados',
    fields: [
      { key: 'rua' },
      { key: 'numero' },
      { key: 'complemento' },
      { key: 'bairro' },
      { key: 'estado', type: 'select', options: ESTADOS_BR },
      { key: 'cidade' },
    ],
  },
  {
    titleKey: 'CONTATO',
    tab: 'dados',
    fields: [{ key: 'empresa_email' }, { key: 'empresa_telefone' }],
  },
  {
    titleKey: 'RESPONSAVEIS',
    tab: 'dados',
    fields: [
      { key: 'responsaveis_empresa' },
      { key: 'responsaveis_alteracoes' },
    ],
  },
  {
    // Renderizados à mão no card Dados da empresa (fora do grid genérico).
    titleKey: 'FISCAL',
    tab: 'dados',
    fields: [{ key: 'razao_social' }, { key: 'inscricao_estadual' }],
  },
  {
    titleKey: 'CONTRATO',
    tab: 'financeiro',
    fields: [
      { key: 'contrato_status', type: 'select', options: CONTRATO_STATUSES },
      { key: 'contrato_valor', type: 'number' },
      { key: 'contrato_inicio', type: 'date' },
      { key: 'contrato_fim', type: 'date' },
    ],
  },
  {
    titleKey: 'ACESSO_TECNICO',
    tab: 'dados',
    // Card com template próprio (não usa fieldsOf) - a lista aqui é o que
    // carrega/detecta alteração/salva. url_painel, ip_host, usuario_acesso e
    // senha_acesso estavam fora dela: apareciam vazios na edição e não salvavam.
    fields: [
      { key: 'site' },
      { key: 'servidor_tipo', type: 'select', options: SERVIDOR_TIPOS },
      { key: 'ultima_versao' },
      { key: 'url_painel' },
      { key: 'ip_host' },
      { key: 'usuario_acesso' },
      { key: 'senha_acesso' },
    ],
  },
  {
    titleKey: 'CONTABILIDADE',
    tab: 'contabilidade',
    fields: [
      { key: 'contador_responsavel' },
      { key: 'contabilidade' },
      { key: 'contabilidade_telefone' },
      { key: 'contabilidade_email' },
      { key: 'regime_tributario', type: 'select', options: REGIME_TRIBUTARIO },
    ],
  },
];
const ALL_EXTRA_FIELDS = FIELD_GROUPS.flatMap(group => group.fields);

const form = reactive({ name: '', domain: '', description: '' });
const customAttrs = reactive(
  Object.fromEntries(
    [
      ...ALL_EXTRA_FIELDS.map(f => f.key),
      'cnpj',
      'cep',
      'dominios_vinculados',
      'urls_acesso',
    ].map(key => [key, ''])
  )
);
const isentaInscricaoEstadual = ref(false);
const observacoes = ref('');
const contabilidadeObservacoes = ref('');
const tipoAcesso = ref([]);
const modulosContratados = ref([]);
const avatarPreviewUrl = ref('');
const editingSection = ref(null);
const isUploadingAvatar = ref(false);

const cnpjLookupLoading = ref(false);
const cnpjLookupNotFound = ref(false);
const cepLookupLoading = ref(false);
const cepLookupNotFound = ref(false);

const uiFlags = computed(() => companiesStore.getUIFlags);
const isUpdating = computed(() => uiFlags.value.updatingItem);
const isAvatarBusy = computed(
  () =>
    isUploadingAvatar.value || uiFlags.value.deletingAvatar || isUpdating.value
);

const displayName = computed(
  () => props.company?.name || t('COMPANIES.UNNAMED')
);
const avatarSource = computed(
  () => avatarPreviewUrl.value || props.company?.avatarUrl || ''
);
const isFormInvalid = computed(() => !form.name.trim());

const arraysDiffer = (a, b) =>
  a.length !== b.length || a.some(item => !b.includes(item));

const hasChanges = computed(() => {
  const attrs = props.company?.customAttributes || {};
  if (
    form.name.trim() !== (props.company?.name || '').trim() ||
    form.domain.trim() !== (props.company?.domain || '').trim() ||
    form.description.trim() !== (props.company?.description || '').trim() ||
    isentaInscricaoEstadual.value !== !!attrs.inscricao_estadual_isenta ||
    observacoes.value !== (attrs.observacoes || '') ||
    contabilidadeObservacoes.value !==
      (attrs.contabilidade_observacoes || '') ||
    customAttrs.cnpj !== (attrs.cnpj || '') ||
    customAttrs.cep !== (attrs.cep || '') ||
    customAttrs.dominios_vinculados !== (attrs.dominios_vinculados || '') ||
    customAttrs.urls_acesso !== (attrs.urls_acesso || '')
  ) {
    return true;
  }
  const savedTipoAcesso = (attrs.tipo_acesso || '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean);
  const savedModulos = (attrs.modulos_contratados || '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean);
  if (
    arraysDiffer(tipoAcesso.value, savedTipoAcesso) ||
    arraysDiffer(modulosContratados.value, savedModulos)
  ) {
    return true;
  }
  return ALL_EXTRA_FIELDS.some(
    field => String(customAttrs[field.key]) !== String(attrs[field.key] || '')
  );
});

const summary = computed(() => {
  const { createdAt, lastActivityAt } = props.company || {};
  return [
    createdAt &&
      t('COMPANIES.DETAIL.PROFILE.CREATED_AT', {
        date: dynamicTime(createdAt),
      }),
    lastActivityAt &&
      t('COMPANIES.DETAIL.PROFILE.LAST_ACTIVE', {
        date: dynamicTime(lastActivityAt),
      }),
  ]
    .filter(Boolean)
    .join(' • ');
});

const splitList = value =>
  (value || '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean);

const syncForm = company => {
  form.name = company?.name || '';
  form.domain = company?.domain || '';
  form.description = company?.description || '';
  const attrs = company?.customAttributes || {};
  ALL_EXTRA_FIELDS.forEach(field => {
    customAttrs[field.key] = attrs[field.key] || '';
  });
  customAttrs.cnpj = attrs.cnpj || '';
  customAttrs.cep = attrs.cep || '';
  customAttrs.dominios_vinculados = attrs.dominios_vinculados || '';
  customAttrs.urls_acesso = attrs.urls_acesso || '';
  isentaInscricaoEstadual.value = !!attrs.inscricao_estadual_isenta;
  observacoes.value = attrs.observacoes || '';
  contabilidadeObservacoes.value = attrs.contabilidade_observacoes || '';
  tipoAcesso.value = splitList(attrs.tipo_acesso);
  modulosContratados.value = splitList(attrs.modulos_contratados);
};

const isCurrentCompany = companyId => Number(props.company?.id) === companyId;

watch(
  () => [
    props.company?.id,
    props.company?.name,
    props.company?.domain,
    props.company?.description,
    props.company?.avatarUrl,
    props.company?.customAttributes,
  ],
  () => {
    avatarPreviewUrl.value = '';
    // Card em edição não pode perder o que está sendo digitado quando chega
    // uma atualização da empresa (ex.: sincronização vinda do Portal).
    if (!editingSection.value) syncForm(props.company);
  },
  { immediate: true, deep: true }
);

const handleAvatarUpload = async ({ file, url }) => {
  avatarPreviewUrl.value = url;
  isUploadingAvatar.value = true;
  try {
    await companiesStore.update({ id: props.company.id, avatar: file });
    useAlert(t('COMPANIES.DETAIL.AVATAR.UPLOAD_SUCCESS'));
  } catch {
    avatarPreviewUrl.value = '';
    useAlert(t('COMPANIES.DETAIL.AVATAR.UPLOAD_ERROR'));
  } finally {
    isUploadingAvatar.value = false;
  }
};

const handleAvatarDelete = async () => {
  try {
    await companiesStore.deleteCompanyAvatar(props.company.id);
    avatarPreviewUrl.value = '';
    useAlert(t('COMPANIES.DETAIL.AVATAR.DELETE_SUCCESS'));
  } catch {
    useAlert(t('COMPANIES.DETAIL.AVATAR.DELETE_ERROR'));
  }
};

function toggleTipoAcesso(tipo) {
  tipoAcesso.value = tipoAcesso.value.includes(tipo)
    ? tipoAcesso.value.filter(t2 => t2 !== tipo)
    : [...tipoAcesso.value, tipo];
}
function toggleModulo(mod) {
  modulosContratados.value = modulosContratados.value.includes(mod)
    ? modulosContratados.value.filter(m => m !== mod)
    : [...modulosContratados.value, mod];
}

function maskCep(raw) {
  const digits = raw.replace(/\D/g, '').slice(0, 8);
  return digits.length <= 5
    ? digits
    : `${digits.slice(0, 5)}-${digits.slice(5)}`;
}
function onCepInput(value) {
  customAttrs.cep = maskCep(value);
}
async function lookupCep() {
  const digits = customAttrs.cep.replace(/\D/g, '');
  if (digits.length !== 8) return;
  cepLookupLoading.value = true;
  cepLookupNotFound.value = false;
  try {
    const res = await fetch(`https://viacep.com.br/ws/${digits}/json/`);
    const data = await res.json();
    if (data.erro) {
      cepLookupNotFound.value = true;
      return;
    }
    if (data.logradouro) customAttrs.rua = data.logradouro;
    if (data.bairro) customAttrs.bairro = data.bairro;
    if (data.localidade) customAttrs.cidade = data.localidade;
    if (data.uf) customAttrs.estado = data.uf;
  } catch {
    cepLookupNotFound.value = true;
  } finally {
    cepLookupLoading.value = false;
    if (cepLookupNotFound.value) {
      setTimeout(() => {
        cepLookupNotFound.value = false;
      }, 2500);
    }
  }
}

function maskCnpj(raw) {
  return raw.replace(/\D/g, '').slice(0, 14);
}
function onCnpjInput(value) {
  customAttrs.cnpj = maskCnpj(value);
}
async function lookupCnpj() {
  const digits = customAttrs.cnpj.replace(/\D/g, '');
  if (digits.length !== 14) return;
  cnpjLookupLoading.value = true;
  cnpjLookupNotFound.value = false;
  try {
    const res = await fetch(`https://brasilapi.com.br/api/cnpj/v1/${digits}`);
    if (!res.ok) {
      cnpjLookupNotFound.value = true;
      return;
    }
    const data = await res.json();
    if (data.razao_social) customAttrs.razao_social = data.razao_social;
    if (data.nome_fantasia || data.razao_social) {
      form.name = data.nome_fantasia || data.razao_social;
    }
    if (data.email) customAttrs.empresa_email = data.email;
    if (data.ddd_telefone_1) customAttrs.empresa_telefone = data.ddd_telefone_1;
    if (data.cep) {
      customAttrs.cep = String(data.cep)
        .replace(/\D/g, '')
        .replace(/^(\d{5})(\d{3})$/, '$1-$2');
    }
    if (data.logradouro) customAttrs.rua = data.logradouro;
    if (data.numero) customAttrs.numero = data.numero;
    if (data.complemento) customAttrs.complemento = data.complemento;
    if (data.bairro) customAttrs.bairro = data.bairro;
    if (data.municipio) customAttrs.cidade = data.municipio;
    if (data.uf) customAttrs.estado = data.uf;
  } catch {
    cnpjLookupNotFound.value = true;
  } finally {
    cnpjLookupLoading.value = false;
    if (cnpjLookupNotFound.value) {
      setTimeout(() => {
        cnpjLookupNotFound.value = false;
      }, 2500);
    }
  }
}

const handleUpdateCompany = async () => {
  const companyId = Number(props.company.id);

  try {
    const updated = await companiesStore.update({
      id: companyId,
      name: form.name.trim(),
      domain: form.domain.trim() || null,
      description: form.description.trim() || null,
      customAttributes: {
        ...Object.fromEntries(
          ALL_EXTRA_FIELDS.map(field => [
            field.key,
            String(customAttrs[field.key]).trim(),
          ])
        ),
        cnpj: customAttrs.cnpj.trim(),
        cep: customAttrs.cep.trim(),
        dominios_vinculados: customAttrs.dominios_vinculados.trim(),
        urls_acesso: customAttrs.urls_acesso.trim(),
        inscricao_estadual_isenta: isentaInscricaoEstadual.value,
        observacoes: observacoes.value.trim(),
        contabilidade_observacoes: contabilidadeObservacoes.value.trim(),
        tipo_acesso: tipoAcesso.value.join(', '),
        modulos_contratados: modulosContratados.value.join(', '),
      },
    });
    if (!isCurrentCompany(companyId)) return false;

    syncForm(updated);
    useAlert(t('COMPANIES.DETAIL.PROFILE.MESSAGES.UPDATE_SUCCESS'));
    return true;
  } catch {
    if (!isCurrentCompany(companyId)) return false;

    useAlert(t('COMPANIES.DETAIL.PROFILE.MESSAGES.UPDATE_ERROR'));
    return false;
  }
};

// ── Ficha em cards (padrão da ficha de Empresa do Portal) ─────────────
// Um card em edição por vez; Cancelar descarta, Salvar manda a empresa
// inteira (mesmo payload de antes) e volta pra leitura.
const startEdit = section => {
  syncForm(props.company);
  editingSection.value = section;
};
const cancelEdit = () => {
  editingSection.value = null;
  syncForm(props.company);
};
const saveSection = async () => {
  if (await handleUpdateCompany()) editingSection.value = null;
};
const cardProps = section => ({
  isEditing: editingSection.value === section,
  canEdit: !editingSection.value,
  isSaving: isUpdating.value,
  saveDisabled: isFormInvalid.value || !hasChanges.value,
});

const fieldsOf = titleKey =>
  FIELD_GROUPS.find(group => group.titleKey === titleKey).fields;

const attrs = computed(() => props.company?.customAttributes || {});
const labelOf = key => t(`COMPANIES.DETAIL.PORTAL_FIELDS.LABELS.${key}`);
const optionLabel = (options, value) =>
  options.find(option => option.value === value)?.label || value || '';
const isTrue = value => value === true || value === 'true';
const readField = (key, extra = {}) => ({
  key,
  label: labelOf(key),
  value: attrs.value[key] || '',
  ...extra,
});
const formatDate = value =>
  value ? new Date(`${value}T00:00:00`).toLocaleDateString(locale.value) : '';
const formatCurrency = value =>
  value === '' ||
  value === null ||
  value === undefined ||
  Number.isNaN(Number(value))
    ? ''
    : Number(value).toLocaleString(locale.value, {
        style: 'currency',
        currency: 'BRL',
      });

const headerSubtitle = computed(() => {
  const place = [attrs.value.cidade, attrs.value.estado]
    .filter(Boolean)
    .join(', ');
  return [attrs.value.cnpj, place].filter(Boolean).join(' · ');
});

const dadosItems = computed(() => [
  readField('razao_social'),
  {
    key: 'name',
    label: labelOf('nome_fantasia'),
    value: props.company?.name || '',
  },
  readField('cnpj', { kind: 'mono' }),
  {
    key: 'inscricao_estadual',
    label: labelOf('inscricao_estadual'),
    value: isTrue(attrs.value.inscricao_estadual_isenta)
      ? t('COMPANIES.DETAIL.INFO_CARD.ISENTA')
      : attrs.value.inscricao_estadual || '',
  },
  readField('segmento'),
  readField('classificacao'),
  {
    key: 'tipo_empresa',
    label: labelOf('tipo_empresa'),
    value: optionLabel(TIPO_EMPRESA_OPTIONS, attrs.value.tipo_empresa),
  },
  {
    key: 'domain',
    label: t('COMPANIES.DETAIL.PROFILE.FIELDS.DOMAIN'),
    value: props.company?.domain || '',
  },
  {
    key: 'description',
    label: t('COMPANIES.DETAIL.INFO_CARD.DESCRIPTION'),
    value: props.company?.description || '',
    kind: 'multiline',
    full: true,
  },
]);

const enderecoItems = computed(() =>
  ['cep', 'rua', 'numero', 'complemento', 'bairro', 'estado', 'cidade'].map(
    key => readField(key)
  )
);

const contatoItems = computed(() =>
  [
    'empresa_email',
    'empresa_telefone',
    'responsaveis_empresa',
    'responsaveis_alteracoes',
  ].map(key => readField(key))
);

const observacoesItems = computed(() => [
  {
    key: 'observacoes',
    label: t('COMPANIES.DETAIL.PORTAL_FIELDS.GROUPS.OBSERVACOES'),
    value: attrs.value.observacoes || '',
    kind: 'multiline',
    full: true,
  },
]);

const contratoItems = computed(() => [
  {
    key: 'contrato_status',
    label: labelOf('contrato_status'),
    value: optionLabel(CONTRATO_STATUSES, attrs.value.contrato_status),
  },
  {
    key: 'contrato_valor',
    label: labelOf('contrato_valor'),
    value: formatCurrency(attrs.value.contrato_valor),
  },
  {
    key: 'contrato_inicio',
    label: labelOf('contrato_inicio'),
    value: formatDate(attrs.value.contrato_inicio),
  },
  {
    key: 'contrato_fim',
    label: labelOf('contrato_fim'),
    value: formatDate(attrs.value.contrato_fim),
  },
  readField('modulos_contratados', {
    value: splitList(attrs.value.modulos_contratados),
    kind: 'chips',
    full: true,
  }),
]);

// Igual ao Portal: URL do painel só pra acesso Nuvem, IP/Usuário/Senha só
// pra acesso Remoto.
const acessoItems = computed(() => {
  const tipos = splitList(attrs.value.tipo_acesso);
  return [
    readField('site'),
    readField('servidor_tipo'),
    readField('ultima_versao'),
    readField('tipo_acesso', { value: tipos, kind: 'chips' }),
    tipos.includes('Nuvem') && readField('url_painel'),
    ...(tipos.includes('Remoto')
      ? [
          readField('ip_host', { kind: 'mono', full: true }),
          readField('usuario_acesso'),
          {
            key: 'senha_acesso',
            label: labelOf('senha_acesso'),
            value: attrs.value.senha_acesso
              ? t('COMPANIES.DETAIL.INFO_CARD.PASSWORD_SET')
              : '',
          },
        ]
      : []),
    readField('urls_acesso', {
      value: splitList(attrs.value.urls_acesso),
      kind: 'chips',
      full: true,
    }),
    readField('dominios_vinculados', {
      value: splitList(attrs.value.dominios_vinculados),
      kind: 'chips',
      full: true,
    }),
  ].filter(Boolean);
});

const contabilidadeItems = computed(() => [
  readField('contador_responsavel'),
  readField('contabilidade'),
  readField('contabilidade_telefone'),
  readField('contabilidade_email'),
  readField('regime_tributario'),
  readField('contabilidade_observacoes', { kind: 'multiline', full: true }),
]);
</script>

<template>
  <div v-if="isLoading && !company?.id" class="text-sm text-n-slate-11">
    {{ t('COMPANIES.DETAIL.LOADING') }}
  </div>

  <div v-else-if="company?.id" class="flex flex-col w-full gap-5 pb-6">
    <div class="flex items-center gap-4">
      <Avatar
        :name="displayName"
        :src="avatarSource"
        :size="56"
        :allow-upload="!isAvatarBusy"
        hide-offline-status
        @upload="handleAvatarUpload"
        @delete="handleAvatarDelete"
      />
      <div class="flex flex-col min-w-0 gap-0.5">
        <h3 class="my-0 text-lg font-semibold truncate text-n-slate-12">
          {{ displayName }}
        </h3>
        <span v-if="headerSubtitle" class="text-sm text-n-slate-11">
          {{ headerSubtitle }}
        </span>
        <span class="text-xs text-n-slate-10">{{ summary }}</span>
        <p
          v-if="isUploadingAvatar || uiFlags.deletingAvatar"
          class="my-0 text-xs text-n-slate-11"
        >
          {{ t('COMPANIES.DETAIL.AVATAR.UPDATING') }}
        </p>
      </div>
    </div>

    <TabBar
      :tabs="CARD_TABS"
      :initial-active-tab="activeTabIndex"
      @tab-changed="handleTabChanged"
    />

    <!-- Aba: Visão geral -->
    <template v-if="activeTabKey === 'dados'">
      <InfoCard
        :title="t('COMPANIES.DETAIL.PORTAL_FIELDS.GROUPS.DADOS_EMPRESA')"
        icon="i-lucide-building-2"
        v-bind="cardProps('dados')"
        @edit="startEdit('dados')"
        @cancel="cancelEdit"
        @save="saveSection"
      >
        <InfoCardFields :items="dadosItems" />
        <template #edit>
          <div class="grid w-full gap-4 sm:grid-cols-2">
            <Input
              v-model="customAttrs.razao_social"
              :label="labelOf('razao_social')"
              :disabled="isUpdating"
              custom-input-class="h-8 !pt-1 !pb-1"
            />
            <Input
              v-model="form.name"
              :label="labelOf('nome_fantasia')"
              :disabled="isUpdating"
              custom-input-class="h-8 !pt-1 !pb-1"
            />
            <div class="relative flex flex-col min-w-0 gap-1">
              <label class="mb-0.5 text-heading-3 text-n-slate-12">
                {{ labelOf('cnpj') }}
              </label>
              <div class="relative">
                <input
                  :value="customAttrs.cnpj"
                  :disabled="isUpdating"
                  :placeholder="
                    t('COMPANIES.DETAIL.PORTAL_FIELDS.CNPJ_PLACEHOLDER')
                  "
                  class="block w-full h-8 !pt-1 !pb-1 reset-base text-sm !mb-0 outline outline-1 border-none border-0 outline-offset-[-1px] rounded-lg bg-n-alpha-black2 outline-n-weak hover:outline-n-slate-6 focus:outline-n-brand text-n-slate-12 pl-3 pr-11"
                  @input="onCnpjInput($event.target.value)"
                  @keydown.enter.prevent="lookupCnpj"
                />
                <button
                  type="button"
                  class="absolute -translate-y-1/2 right-2 top-1/2 flex items-center justify-center w-6 h-6 p-0 border-0 bg-transparent text-n-slate-11 hover:text-n-slate-12 disabled:opacity-40"
                  :disabled="
                    isUpdating ||
                    customAttrs.cnpj.replace(/\D/g, '').length !== 14
                  "
                  :title="t('COMPANIES.DETAIL.PORTAL_FIELDS.CNPJ_LOOKUP_TITLE')"
                  @click="lookupCnpj"
                >
                  <Icon
                    :icon="
                      cnpjLookupLoading
                        ? 'i-lucide-loader-2'
                        : 'i-lucide-search'
                    "
                    class="size-4"
                    :class="{ 'animate-spin': cnpjLookupLoading }"
                  />
                </button>
              </div>
              <p
                v-if="cnpjLookupNotFound"
                class="text-label-small text-n-amber-11"
              >
                {{ t('COMPANIES.DETAIL.PORTAL_FIELDS.CNPJ_NOT_FOUND') }}
              </p>
            </div>
            <div class="flex flex-col gap-2">
              <Input
                v-model="customAttrs.inscricao_estadual"
                :label="labelOf('inscricao_estadual')"
                :disabled="isUpdating || isentaInscricaoEstadual"
                custom-input-class="h-8 !pt-1 !pb-1"
              />
              <label class="flex items-center gap-2 cursor-pointer w-fit">
                <Checkbox
                  v-model="isentaInscricaoEstadual"
                  :disabled="isUpdating"
                />
                <span class="text-sm text-n-slate-12">
                  {{ labelOf('inscricao_estadual_isenta') }}
                </span>
              </label>
            </div>
            <template
              v-for="field in fieldsOf('DADOS_EMPRESA')"
              :key="field.key"
            >
              <Select
                v-if="field.type === 'select'"
                v-model="customAttrs[field.key]"
                :options="field.options"
                :label="labelOf(field.key)"
                :disabled="isUpdating"
                class="w-full"
              />
              <Input
                v-else
                v-model="customAttrs[field.key]"
                :label="labelOf(field.key)"
                :disabled="isUpdating"
                custom-input-class="h-8 !pt-1 !pb-1"
              />
            </template>
            <Input
              v-model="form.domain"
              :label="t('COMPANIES.DETAIL.PROFILE.FIELDS.DOMAIN')"
              :disabled="isUpdating"
              custom-input-class="h-8 !pt-1 !pb-1"
            />
            <div class="flex flex-col gap-1 sm:col-span-2">
              <label class="mb-0.5 text-heading-3 text-n-slate-12">
                {{ t('COMPANIES.DETAIL.INFO_CARD.DESCRIPTION') }}
              </label>
              <TextArea
                v-model="form.description"
                :placeholder="
                  t('COMPANIES.DETAIL.PROFILE.DESCRIPTION_PLACEHOLDER')
                "
                :disabled="isUpdating"
                :max-length="280"
                class="w-full"
                show-character-count
                auto-height
              />
            </div>
          </div>
        </template>
      </InfoCard>

      <InfoCard
        :title="t('COMPANIES.DETAIL.PORTAL_FIELDS.GROUPS.ENDERECO')"
        icon="i-lucide-map-pin"
        v-bind="cardProps('endereco')"
        @edit="startEdit('endereco')"
        @cancel="cancelEdit"
        @save="saveSection"
      >
        <InfoCardFields :items="enderecoItems" />
        <template #edit>
          <div class="grid w-full gap-4 sm:grid-cols-2">
            <div class="relative flex flex-col min-w-0 gap-1">
              <label class="mb-0.5 text-heading-3 text-n-slate-12">
                {{ labelOf('cep') }}
              </label>
              <div class="relative">
                <input
                  :value="customAttrs.cep"
                  :disabled="isUpdating"
                  :placeholder="
                    t('COMPANIES.DETAIL.PORTAL_FIELDS.CEP_PLACEHOLDER')
                  "
                  class="block w-full h-8 !pt-1 !pb-1 reset-base text-sm !mb-0 outline outline-1 border-none border-0 outline-offset-[-1px] rounded-lg bg-n-alpha-black2 outline-n-weak hover:outline-n-slate-6 focus:outline-n-brand text-n-slate-12 pl-3 pr-11"
                  @input="onCepInput($event.target.value)"
                  @keydown.enter.prevent="lookupCep"
                />
                <button
                  type="button"
                  class="absolute -translate-y-1/2 right-2 top-1/2 flex items-center justify-center w-6 h-6 p-0 border-0 bg-transparent text-n-slate-11 hover:text-n-slate-12 disabled:opacity-40"
                  :disabled="
                    isUpdating ||
                    customAttrs.cep.replace(/\D/g, '').length !== 8
                  "
                  :title="t('COMPANIES.DETAIL.PORTAL_FIELDS.CEP_LOOKUP_TITLE')"
                  @click="lookupCep"
                >
                  <Icon
                    :icon="
                      cepLookupLoading ? 'i-lucide-loader-2' : 'i-lucide-search'
                    "
                    class="size-4"
                    :class="{ 'animate-spin': cepLookupLoading }"
                  />
                </button>
              </div>
              <p
                v-if="cepLookupNotFound"
                class="text-label-small text-n-amber-11"
              >
                {{ t('COMPANIES.DETAIL.PORTAL_FIELDS.CEP_NOT_FOUND') }}
              </p>
            </div>
            <template v-for="field in fieldsOf('ENDERECO')" :key="field.key">
              <Select
                v-if="field.type === 'select'"
                v-model="customAttrs[field.key]"
                :options="field.options"
                :label="labelOf(field.key)"
                :disabled="isUpdating"
                class="w-full"
              />
              <Input
                v-else
                v-model="customAttrs[field.key]"
                :label="labelOf(field.key)"
                :disabled="isUpdating"
                custom-input-class="h-8 !pt-1 !pb-1"
              />
            </template>
          </div>
        </template>
      </InfoCard>

      <InfoCard
        :title="t('COMPANIES.DETAIL.PORTAL_FIELDS.GROUPS.CONTATO')"
        icon="i-lucide-phone"
        v-bind="cardProps('contato')"
        @edit="startEdit('contato')"
        @cancel="cancelEdit"
        @save="saveSection"
      >
        <InfoCardFields :items="contatoItems" />
        <template #edit>
          <div class="grid w-full gap-4 sm:grid-cols-2">
            <Input
              v-for="field in [
                ...fieldsOf('CONTATO'),
                ...fieldsOf('RESPONSAVEIS'),
              ]"
              :key="field.key"
              v-model="customAttrs[field.key]"
              :label="labelOf(field.key)"
              :disabled="isUpdating"
              custom-input-class="h-8 !pt-1 !pb-1"
            />
          </div>
        </template>
      </InfoCard>

      <InfoCard
        :title="t('COMPANIES.DETAIL.INFO_CARD.URLS_ACESSO')"
        icon="i-lucide-link"
        v-bind="cardProps('tecnico')"
        @edit="startEdit('tecnico')"
        @cancel="cancelEdit"
        @save="saveSection"
      >
        <InfoCardFields :items="acessoItems" />
        <template #edit>
          <div class="flex flex-col w-full gap-4">
            <div class="grid w-full gap-4 sm:grid-cols-2">
              <Input
                v-model="customAttrs.site"
                :label="labelOf('site')"
                :disabled="isUpdating"
                custom-input-class="h-8 !pt-1 !pb-1"
              />
              <Select
                v-model="customAttrs.servidor_tipo"
                :options="SERVIDOR_TIPOS"
                :label="labelOf('servidor_tipo')"
                :disabled="isUpdating"
              />
              <Input
                v-model="customAttrs.ultima_versao"
                :label="labelOf('ultima_versao')"
                :disabled="isUpdating"
                custom-input-class="h-8 !pt-1 !pb-1"
              />
            </div>
            <div class="flex flex-col w-full gap-2">
              <span class="text-heading-3 text-n-slate-12">
                {{ labelOf('tipo_acesso') }}
              </span>
              <div class="flex items-center gap-4">
                <label
                  v-for="tipo in TIPOS_ACESSO"
                  :key="tipo"
                  class="flex items-center gap-2 text-sm cursor-pointer text-n-slate-12"
                >
                  <Checkbox
                    :model-value="tipoAcesso.includes(tipo)"
                    :disabled="isUpdating"
                    @update:model-value="toggleTipoAcesso(tipo)"
                  />
                  {{ tipo }}
                </label>
              </div>
            </div>
            <Input
              v-if="tipoAcesso.includes('Nuvem')"
              v-model="customAttrs.url_painel"
              :label="labelOf('url_painel')"
              :disabled="isUpdating"
              custom-input-class="h-8 !pt-1 !pb-1"
            />
            <div
              v-if="tipoAcesso.includes('Remoto')"
              class="grid w-full gap-4 sm:grid-cols-2"
            >
              <Input
                v-model="customAttrs.ip_host"
                :label="labelOf('ip_host')"
                :disabled="isUpdating"
                custom-input-class="h-8 !pt-1 !pb-1"
              />
              <Input
                v-model="customAttrs.usuario_acesso"
                :label="labelOf('usuario_acesso')"
                :disabled="isUpdating"
                custom-input-class="h-8 !pt-1 !pb-1"
              />
              <Input
                v-model="customAttrs.senha_acesso"
                type="password"
                :label="labelOf('senha_acesso')"
                :disabled="isUpdating"
                custom-input-class="h-8 !pt-1 !pb-1"
              />
            </div>
            <div class="grid w-full gap-4 sm:grid-cols-2">
              <Input
                v-model="customAttrs.urls_acesso"
                :label="labelOf('urls_acesso')"
                :disabled="isUpdating"
                custom-input-class="h-8 !pt-1 !pb-1"
              />
              <Input
                v-model="customAttrs.dominios_vinculados"
                :label="labelOf('dominios_vinculados')"
                :disabled="isUpdating"
                custom-input-class="h-8 !pt-1 !pb-1"
              />
            </div>
          </div>
        </template>
      </InfoCard>

      <InfoCard
        :title="t('COMPANIES.DETAIL.PORTAL_FIELDS.GROUPS.OBSERVACOES')"
        icon="i-lucide-file-text"
        v-bind="cardProps('observacoes')"
        @edit="startEdit('observacoes')"
        @cancel="cancelEdit"
        @save="saveSection"
      >
        <InfoCardFields :items="observacoesItems" />
        <template #edit>
          <TextArea
            v-model="observacoes"
            :disabled="isUpdating"
            class="w-full"
            auto-height
          />
        </template>
      </InfoCard>
    </template>

    <!-- Aba: Financeiro (Contrato) - restrita ao perfil Financeiro/admin -->
    <InfoCard
      v-if="activeTabKey === 'financeiro' && canViewFinanceiro"
      :title="t('COMPANIES.DETAIL.PORTAL_FIELDS.GROUPS.CONTRATO')"
      icon="i-lucide-file-signature"
      v-bind="cardProps('contrato')"
      @edit="startEdit('contrato')"
      @cancel="cancelEdit"
      @save="saveSection"
    >
      <InfoCardFields :items="contratoItems" />
      <template #edit>
        <div class="flex flex-col w-full gap-4">
          <div class="grid w-full gap-4 sm:grid-cols-2">
            <template v-for="field in fieldsOf('CONTRATO')" :key="field.key">
              <Select
                v-if="field.type === 'select'"
                v-model="customAttrs[field.key]"
                :options="field.options"
                :label="labelOf(field.key)"
                :disabled="isUpdating"
                class="w-full"
              />
              <Input
                v-else
                v-model="customAttrs[field.key]"
                :type="field.type"
                :label="labelOf(field.key)"
                :disabled="isUpdating"
                custom-input-class="h-8 !pt-1 !pb-1"
              />
            </template>
          </div>
          <div class="flex flex-col w-full gap-2">
            <span class="text-heading-3 text-n-slate-12">
              {{ labelOf('modulos_contratados') }}
            </span>
            <div
              class="grid w-full grid-cols-1 gap-1 p-3 border rounded-lg sm:grid-cols-2 border-n-weak"
            >
              <label
                v-for="mod in ALBATROSS_MODULOS"
                :key="mod"
                class="flex items-center gap-2 py-1 text-sm cursor-pointer text-n-slate-12"
              >
                <Checkbox
                  :model-value="modulosContratados.includes(mod)"
                  :disabled="isUpdating"
                  @update:model-value="toggleModulo(mod)"
                />
                {{ mod }}
              </label>
            </div>
          </div>
        </div>
      </template>
    </InfoCard>

    <!-- Aba: Contabilidade - aberta pra qualquer agente -->
    <InfoCard
      v-if="activeTabKey === 'contabilidade'"
      :title="t('COMPANIES.DETAIL.PORTAL_FIELDS.GROUPS.CONTABILIDADE')"
      icon="i-lucide-calculator"
      v-bind="cardProps('contabilidade')"
      @edit="startEdit('contabilidade')"
      @cancel="cancelEdit"
      @save="saveSection"
    >
      <InfoCardFields :items="contabilidadeItems" />
      <template #edit>
        <div class="flex flex-col w-full gap-4">
          <div class="grid w-full gap-4 sm:grid-cols-2">
            <template
              v-for="field in fieldsOf('CONTABILIDADE')"
              :key="field.key"
            >
              <Select
                v-if="field.type === 'select'"
                v-model="customAttrs[field.key]"
                :options="field.options"
                :label="labelOf(field.key)"
                :disabled="isUpdating"
                class="w-full"
              />
              <Input
                v-else
                v-model="customAttrs[field.key]"
                :label="labelOf(field.key)"
                :disabled="isUpdating"
                custom-input-class="h-8 !pt-1 !pb-1"
              />
            </template>
          </div>
          <div class="flex flex-col w-full gap-2">
            <span class="text-heading-3 text-n-slate-12">
              {{ labelOf('contabilidade_observacoes') }}
            </span>
            <TextArea
              v-model="contabilidadeObservacoes"
              :disabled="isUpdating"
              class="w-full"
              auto-height
            />
          </div>
        </div>
      </template>
    </InfoCard>
  </div>
</template>
