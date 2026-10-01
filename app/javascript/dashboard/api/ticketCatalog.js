// PATCH LOCAL (fork) - cadastros de atendimento (Serviços, Categorias, Status,
// Justificativas, Motivos de encerramento, Campos adicionais e Regras de exibição). Só
// index/show/create/update: nada é excluído, só inativado.
import ApiClient from './ApiClient';

const catalogApi = resource => new ApiClient(resource, { accountScoped: true });

export const ticketServicesAPI = catalogApi('ticket_services');
export const ticketCategoriesAPI = catalogApi('ticket_categories');
export const ticketStatusesAPI = catalogApi('ticket_statuses');
export const ticketJustificationsAPI = catalogApi('ticket_justifications');
export const ticketCloseReasonsAPI = catalogApi('ticket_close_reasons');
export const ticketCustomFieldsAPI = catalogApi('ticket_custom_fields');
export const ticketFieldRulesAPI = catalogApi('ticket_field_rules');
