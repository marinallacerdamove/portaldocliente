// PATCH LOCAL (fork) - chaves de custom_attributes da conversa, contrato com o
// Portal do Cliente e com o servidor (TicketContract no Ruby, mesmos valores;
// spec/fixtures/fork_parity/ticket_contract.json confere os dois lados).
// Campos adicionais (regras de exibição) ficam todos em
// custom_attributes.campos_adicionais e têm o próprio acordeão na lateral.
import { CUSTOM_FIELDS_ATTRIBUTE_KEY } from 'dashboard/helper/ticketFieldRules';

export const ASSUNTO_ATTRIBUTE_KEY = 'assunto';
export const PRODUTO_ATTRIBUTE_KEY = 'produto';
export const TICKET_ID_EXTERNO_ATTRIBUTE_KEY = 'ticket_id_externo';
export const TICKET_PAI_ID_ATTRIBUTE_KEY = 'ticket_pai_id';
export const TICKET_FILHOS_IDS_ATTRIBUTE_KEY = 'ticket_filhos_ids';
export const VISIVEL_PARCEIRO_ATTRIBUTE_KEY = 'visivel_parceiro';

// Código de negócio do item do cadastro escolhido na conversa (chaves ocultas,
// o servidor mantém junto do nome: TicketCatalogCodes).
export const SERVICO_CODIGO_ATTRIBUTE_KEY = 'servico_codigo';
export const TIPO_DE_SOLICITACAO_CODIGO_ATTRIBUTE_KEY =
  'tipo_de_solicitao_codigo';
export const STATUS_ATENDIMENTO_CODIGO_ATTRIBUTE_KEY =
  'status_atendimento_codigo';
export const JUSTIFICATIVA_CODIGO_ATTRIBUTE_KEY = 'justificativa_codigo';
export const MOTIVO_ENCERRAMENTO_CODIGO_ATTRIBUTE_KEY =
  'motivo_encerramento_codigo';

// Conversation custom attribute keys que vêm do sync do Portal do Cliente,
// mostrados na seção "Informações do Portal do Cliente" - reduzido a só o
// protocolo (os campos de classificação do ticket viraram campo de verdade
// em "Ações da conversa", ver SERVICO_ATTRIBUTE_KEY e afins logo abaixo).
// 'ticket_id' fica de fora de propósito - já aparece sozinho no cabeçalho da
// conversa (ConversationHeader.vue) como "#74"; listar de novo aqui duplicava
// o mesmo número na tela.
export const PORTAL_INFO_ATTRIBUTE_KEYS = Object.freeze([
  TICKET_ID_EXTERNO_ATTRIBUTE_KEY,
]);

// Campos que o sync do Portal ainda preenche mas que não têm mais home
// nenhuma na sidebar - a informação já aparece em outro lugar (assunto é o
// próprio título da conversa; produto é redundante com o caminho completo de
// Serviço; sla_horas/prazo_resolucao e visivel_parceiro são derivados/
// internos; motivo_encerramento tem o próprio fluxo nativo de "Resolver").
// Só entram aqui pra sumir de "Informação da conversa" - nunca em includeKeys.
export const MOTIVO_ENCERRAMENTO_ATTRIBUTE_KEY = 'motivo_encerramento';
export const SUPERSEDED_PORTAL_ATTRIBUTE_KEYS = Object.freeze([
  ASSUNTO_ATTRIBUTE_KEY,
  PRODUTO_ATTRIBUTE_KEY,
  'sla_horas',
  'prazo_resolucao',
  VISIVEL_PARCEIRO_ATTRIBUTE_KEY,
  MOTIVO_ENCERRAMENTO_ATTRIBUTE_KEY,
]);

// Rendered inline in ConversationAction.vue ("Ações da conversa"), alongside
// Assignee/Team/Priority - ainda precisam ser excluídos de "Informação da
// conversa". Tipo de solicitação (cadastro, limitado pelo serviço) e
// Empresa ficam antes de Serviço.
export const SERVICO_ATTRIBUTE_KEY = 'servico';
export const TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY = 'tipo_de_solicitao';
export const EMPRESA_ATTRIBUTE_KEY = 'empresa';
// PATCH LOCAL (fork) - Status e Justificativa (cadastros de atendimento)
// também são seletores próprios em "Ações da conversa".
export const STATUS_ATENDIMENTO_ATTRIBUTE_KEY = 'status_atendimento';
export const JUSTIFICATIVA_ATTRIBUTE_KEY = 'justificativa';

// Rendered inline in ConversationAction.vue as the Ticket Pai/Filhos links -
// raw values, never meant to appear as generic custom-attribute fields.
export const TICKET_LINK_ATTRIBUTE_KEYS = Object.freeze([
  TICKET_PAI_ID_ATTRIBUTE_KEY,
  TICKET_FILHOS_IDS_ATTRIBUTE_KEY,
]);

// Rendered no cabeçalho da conversa (ConversationHeader.vue), não na barra
// lateral - ainda precisa ficar fora de "Informação da conversa"/"Informações
// do Portal do Cliente" pra não duplicar o mesmo número na tela.
export const HEADER_ATTRIBUTE_KEYS = Object.freeze(['ticket_id']);

// Every conversation_attribute key that has a dedicated home elsewhere in the
// sidebar - used to decide whether "Informação da conversa" has anything
// left to show at all.
export const ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS = Object.freeze([
  ...PORTAL_INFO_ATTRIBUTE_KEYS,
  ...SUPERSEDED_PORTAL_ATTRIBUTE_KEYS,
  SERVICO_ATTRIBUTE_KEY,
  TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY,
  EMPRESA_ATTRIBUTE_KEY,
  STATUS_ATENDIMENTO_ATTRIBUTE_KEY,
  JUSTIFICATIVA_ATTRIBUTE_KEY,
  CUSTOM_FIELDS_ATTRIBUTE_KEY,
  ...TICKET_LINK_ATTRIBUTE_KEYS,
  ...HEADER_ATTRIBUTE_KEYS,
]);
