import * as keys from 'dashboard/constants/ticketDetailAttributes';
import { CUSTOM_FIELDS_ATTRIBUTE_KEY } from 'dashboard/helper/ticketFieldRules';
import { INTERNAL_TICKETS_INBOX_NAME } from 'dashboard/composables/useTicketCatalog';
import { CHANNEL_ORIGINS } from 'dashboard/composables/useConversationCustomFields';
import contract from '../../../../../spec/fixtures/fork_parity/ticket_contract.json';

// Mesmo arquivo lido por spec/models/ticket_contract_spec.rb (TicketContract):
// mudar uma chave de um lado só quebra um dos dois.
describe('ticket contract parity with the server', () => {
  it('uses the same custom attribute keys as TicketContract', () => {
    expect({
      SERVICE_KEY: keys.SERVICO_ATTRIBUTE_KEY,
      CATEGORY_KEY: keys.TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY,
      STATUS_KEY: keys.STATUS_ATENDIMENTO_ATTRIBUTE_KEY,
      JUSTIFICATION_KEY: keys.JUSTIFICATIVA_ATTRIBUTE_KEY,
      CLOSE_REASON_KEY: keys.MOTIVO_ENCERRAMENTO_ATTRIBUTE_KEY,
      CUSTOM_FIELDS_KEY: CUSTOM_FIELDS_ATTRIBUTE_KEY,
      COMPANY_KEY: keys.EMPRESA_ATTRIBUTE_KEY,
      SUBJECT_KEY: keys.ASSUNTO_ATTRIBUTE_KEY,
      PRODUCT_KEY: keys.PRODUTO_ATTRIBUTE_KEY,
      EXTERNAL_TICKET_ID_KEY: keys.TICKET_ID_EXTERNO_ATTRIBUTE_KEY,
      PARENT_TICKET_KEY: keys.TICKET_PAI_ID_ATTRIBUTE_KEY,
      CHILD_TICKETS_KEY: keys.TICKET_FILHOS_IDS_ATTRIBUTE_KEY,
    }).toEqual(contract.attribute_keys);
  });

  it('names the internal tickets inbox like the server', () => {
    expect(INTERNAL_TICKETS_INBOX_NAME).toBe(
      contract.internal_tickets_inbox_name
    );
  });

  it('maps channel origins like ResolveRequirementsService', () => {
    expect(CHANNEL_ORIGINS).toEqual(contract.channel_origins);
  });
});
