// PATCH LOCAL (fork) - conversa de WhatsApp não vira ticket no Portal sozinha: ao
// encerrar, o agente decide ("Criar ticket desta conversa no Portal?"). A
// pergunta só aparece quando faz sentido: canal WhatsApp e a conversa ainda
// sem ticket (o Portal grava ticket_id na conversa quando ela já virou ticket).
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { TICKET_ID_ATTRIBUTE_KEY } from 'dashboard/constants/ticketDetailAttributes';

export const shouldOfferPortalTicket = conversation => {
  if (conversation?.meta?.channel !== INBOX_TYPES.WHATSAPP) return false;
  return !conversation.custom_attributes?.[TICKET_ID_ATTRIBUTE_KEY];
};
