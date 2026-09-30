// PATCH LOCAL (fork) - variáveis do menu "Variáveis" (macros) e do {{ no
// editor, com nome em português. Mesmas chaves que o backend resolve no envio
// (Liquid: TicketDrop, PortalVariables, ContactDrop, UserDrop...).
const TIME_ZONE = 'America/Sao_Paulo';

export const PORTAL_VARIABLE_GROUPS = [
  {
    key: 'TICKET',
    variables: [
      { key: 'ticket.numero', label: 'TICKET_NUMBER' },
      { key: 'ticket.assunto', label: 'TICKET_SUBJECT' },
      { key: 'ticket.servico', label: 'TICKET_SERVICE' },
      { key: 'ticket.tipo_de_solicitacao', label: 'TICKET_REQUEST_TYPE' },
      { key: 'ticket.produto', label: 'TICKET_PRODUCT' },
      { key: 'ticket.empresa', label: 'TICKET_COMPANY' },
      { key: 'ticket.cpf_cnpj', label: 'TICKET_CPF_CNPJ' },
    ],
  },
  {
    key: 'CONTACT',
    variables: [
      { key: 'contact.first_name', label: 'CONTACT_FIRST_NAME' },
      { key: 'contact.name', label: 'CONTACT_NAME' },
      { key: 'contact.email', label: 'CONTACT_EMAIL' },
      { key: 'contact.phone', label: 'CONTACT_PHONE' },
    ],
  },
  {
    key: 'AGENT',
    variables: [
      { key: 'agent.first_name', label: 'AGENT_FIRST_NAME' },
      { key: 'agent.name', label: 'AGENT_NAME' },
      { key: 'agent.email', label: 'AGENT_EMAIL' },
    ],
  },
  {
    key: 'OTHER',
    variables: [
      { key: 'saudacao', label: 'GREETING' },
      { key: 'account.name', label: 'ACCOUNT_NAME' },
      { key: 'inbox.name', label: 'INBOX_NAME' },
      { key: 'conversation.id', label: 'CONVERSATION_ID' },
    ],
  },
];

export const PORTAL_VARIABLES = PORTAL_VARIABLE_GROUPS.flatMap(
  group => group.variables
);

// "Bom dia" / "Boa tarde" / "Boa noite" no horário de Brasília (igual ao
// PortalVariables.greeting do backend).
export const greeting = (date = new Date()) => {
  const hour = Number(
    new Intl.DateTimeFormat('pt-BR', {
      hour: 'numeric',
      hourCycle: 'h23',
      timeZone: TIME_ZONE,
    }).format(date)
  );
  if (hour < 12) return 'Bom dia';
  if (hour < 18) return 'Boa tarde';
  return 'Boa noite';
};

// Valores das variáveis que o getMessageVariables do upstream não conhece.
// `company`: empresa do contato (store de empresas), pro CPF/CNPJ.
export const getPortalVariableValues = (conversation, company) => {
  const attributes = conversation?.custom_attributes || {};
  return {
    saudacao: greeting(),
    'ticket.numero': attributes.ticket_id_externo || conversation?.id,
    'ticket.assunto': attributes.assunto,
    'ticket.servico': attributes.servico,
    'ticket.tipo_de_solicitacao': attributes.tipo_de_solicitao,
    'ticket.produto': attributes.produto,
    'ticket.empresa': attributes.empresa,
    'ticket.cpf_cnpj': company?.customAttributes?.cnpj,
  };
};
