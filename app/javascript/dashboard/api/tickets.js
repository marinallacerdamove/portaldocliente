/* global axios */
// PATCH LOCAL (fork) - gravações de ticket que o servidor faz numa chamada só:
// custom_attributes por merge (só as chaves alteradas), vínculo pai/filho
// (Conversations::TicketLinkService) e criação do ticket completo
// (Conversations::InternalTicketService).
import ApiClient from './ApiClient';

class TicketsAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  // `remove`: chaves apagadas na mesma gravação.
  mergeCustomAttributes({ conversationId, customAttributes, remove }) {
    return axios.post(`${this.url}/${conversationId}/custom_attributes`, {
      custom_attributes: customAttributes,
      merge: true,
      remove,
    });
  }

  // relation: papel do ticketId em relação à conversa ('parent' | 'child').
  link({ conversationId, relation, ticketId }) {
    return axios.post(`${this.url}/${conversationId}/ticket_link`, {
      relation,
      ticket_id: ticketId,
    });
  }

  // ticket: { inbox_id, contact_id, team_id, assignee_id, priority,
  // custom_attributes, message: { content, private }, copy: {
  // source_conversation_id, message_ids }, watcher_ids, link: {
  // conversation_id, relation, announce } }. Multipart por causa dos anexos.
  createInternalTicket(ticket, attachments = []) {
    const payload = new FormData();
    payload.append('ticket', JSON.stringify(ticket));
    attachments.forEach(file => payload.append('attachments[]', file));
    return axios.post(`${this.baseUrl()}/internal_tickets`, payload);
  }
}

export default new TicketsAPI();
