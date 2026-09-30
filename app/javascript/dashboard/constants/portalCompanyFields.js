// Espelha as mesmas listas fixas do formulário de Empresa no Portal do
// Cliente (frontend/src/constants/empresa.js e constants/brasil.js) - os
// dois códigos não compartilham import (repositórios separados), por isso
// duplicado aqui. Se a lista mudar no Portal, precisa atualizar os dois.
export const SEGMENTOS = [
  'Tecnologia da Informação',
  'Varejo',
  'Saúde',
  'Educação',
  'Financeiro',
  'Indústria',
  'Serviços',
  'Outro',
].map(value => ({ value, label: value }));

export const CLASSIFICACOES = ['A', 'B', 'C'].map(value => ({
  value,
  label: value,
}));

export const SERVIDOR_TIPOS = ['Windows', 'Linux', 'Nuvem (SaaS)', 'Outro'].map(
  value => ({ value, label: value })
);

export const TIPOS_ACESSO = ['Remoto', 'Nuvem'];

export const CONTRATO_STATUSES = [
  { value: 'ativo', label: 'Ativo' },
  { value: 'em_renovacao', label: 'Em renovação' },
  { value: 'cancelado', label: 'Cancelado' },
  { value: 'inadimplente', label: 'Inadimplente' },
];

export const ALBATROSS_MODULOS = [
  '01. Stakeholders',
  '02. Suprimentos',
  '03. WMS - Warehouse Management System',
  '04. Comercial',
  '05. Finanças',
  '06. Logística',
  '07. PCP - Planej. e Contr. da Produção',
  '08. Serviços',
  '09. RH - Recursos Humanos',
  '10. CRM - Customer Relationship Management',
  '11. Fiscal',
  '12. Contabilidade',
  '13. Gestão de Contratos e Documentos',
  '14. Gestão de Ativos',
  '15. Gestão de Projetos',
  '16. Ferramentas / Configurações',
];

export const REGIME_TRIBUTARIO = [
  'SIMPLES NACIONAL PURO',
  'SIMPLES NACIONAL HIBRIDO',
  'LUCRO PRESUMIDO',
  'LUCRO REAL',
  'PRODUTOR RURAL',
].map(value => ({ value, label: value }));

export const TIPO_EMPRESA_OPTIONS = [
  { value: 'matriz', label: 'Matriz' },
  { value: 'filial', label: 'Filial' },
];

export const ESTADOS_BR = [
  { value: 'AC', label: 'Acre' },
  { value: 'AL', label: 'Alagoas' },
  { value: 'AP', label: 'Amapá' },
  { value: 'AM', label: 'Amazonas' },
  { value: 'BA', label: 'Bahia' },
  { value: 'CE', label: 'Ceará' },
  { value: 'DF', label: 'Distrito Federal' },
  { value: 'ES', label: 'Espírito Santo' },
  { value: 'GO', label: 'Goiás' },
  { value: 'MA', label: 'Maranhão' },
  { value: 'MT', label: 'Mato Grosso' },
  { value: 'MS', label: 'Mato Grosso do Sul' },
  { value: 'MG', label: 'Minas Gerais' },
  { value: 'PA', label: 'Pará' },
  { value: 'PB', label: 'Paraíba' },
  { value: 'PR', label: 'Paraná' },
  { value: 'PE', label: 'Pernambuco' },
  { value: 'PI', label: 'Piauí' },
  { value: 'RJ', label: 'Rio de Janeiro' },
  { value: 'RN', label: 'Rio Grande do Norte' },
  { value: 'RS', label: 'Rio Grande do Sul' },
  { value: 'RO', label: 'Rondônia' },
  { value: 'RR', label: 'Roraima' },
  { value: 'SC', label: 'Santa Catarina' },
  { value: 'SP', label: 'São Paulo' },
  { value: 'SE', label: 'Sergipe' },
  { value: 'TO', label: 'Tocantins' },
];

// Mesmas categorias da aba Documentos da empresa no Portal
// (Empresa::FILE_CATEGORIES / frontend/src/constants/empresa.js lá).
export const FILE_CATEGORIAS = [
  { value: 'implantacao', label: 'Implantação' },
  { value: 'suporte', label: 'Suporte' },
  { value: 'financeiro', label: 'Financeiro' },
];
