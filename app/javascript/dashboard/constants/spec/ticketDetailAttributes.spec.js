import {
  PORTAL_INFO_ATTRIBUTE_KEYS,
  SUPERSEDED_PORTAL_ATTRIBUTE_KEYS,
  SERVICO_ATTRIBUTE_KEY,
  TIPO_DE_SOLICITACAO_ATTRIBUTE_KEY,
  EMPRESA_ATTRIBUTE_KEY,
  STATUS_ATENDIMENTO_ATTRIBUTE_KEY,
  JUSTIFICATIVA_ATTRIBUTE_KEY,
  TICKET_LINK_ATTRIBUTE_KEYS,
  HEADER_ATTRIBUTE_KEYS,
  ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS,
} from 'dashboard/constants/ticketDetailAttributes';
import { CUSTOM_FIELDS_ATTRIBUTE_KEY } from 'dashboard/helper/ticketFieldRules';

describe('ticketDetailAttributes', () => {
  it('freezes every exported key list so callers cannot mutate them', () => {
    expect(Object.isFrozen(PORTAL_INFO_ATTRIBUTE_KEYS)).toBe(true);
    expect(Object.isFrozen(TICKET_LINK_ATTRIBUTE_KEYS)).toBe(true);
    expect(Object.isFrozen(ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS)).toBe(true);
  });

  it('does not list ticket_id under PORTAL_INFO_ATTRIBUTE_KEYS', () => {
    // ticket_id already renders in ConversationHeader.vue ("#74") - listing
    // it again in the "Informações do Portal do Cliente" panel duplicated
    // the same number on screen.
    expect(PORTAL_INFO_ATTRIBUTE_KEYS).not.toContain('ticket_id');
    expect(HEADER_ATTRIBUTE_KEYS).toContain('ticket_id');
  });

  it('combines every curated group into ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS with no duplicates', () => {
    const expected = [
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
    ];

    expect(ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS).toEqual(expected);
    expect(new Set(ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS).size).toBe(
      ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS.length
    );
  });
});
