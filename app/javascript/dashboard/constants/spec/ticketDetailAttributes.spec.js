import {
  TICKET_DETAIL_ATTRIBUTE_KEYS,
  PORTAL_INFO_ATTRIBUTE_KEYS,
  SERVICO_ATTRIBUTE_KEY,
  TICKET_LINK_ATTRIBUTE_KEYS,
  ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS,
} from 'dashboard/constants/ticketDetailAttributes';

describe('ticketDetailAttributes', () => {
  it('freezes every exported key list so callers cannot mutate them', () => {
    expect(Object.isFrozen(TICKET_DETAIL_ATTRIBUTE_KEYS)).toBe(true);
    expect(Object.isFrozen(PORTAL_INFO_ATTRIBUTE_KEYS)).toBe(true);
    expect(Object.isFrozen(TICKET_LINK_ATTRIBUTE_KEYS)).toBe(true);
    expect(Object.isFrozen(ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS)).toBe(true);
  });

  it('does not list servico under TICKET_DETAIL_ATTRIBUTE_KEYS', () => {
    // servico is rendered inline in ConversationAction.vue, not through the
    // generic CustomAttributes component — regression test for a reordering
    // bug that happened when it lived in both places at once.
    expect(TICKET_DETAIL_ATTRIBUTE_KEYS).not.toContain(SERVICO_ATTRIBUTE_KEY);
  });

  it('combines every curated group into ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS with no duplicates', () => {
    const expected = [
      ...TICKET_DETAIL_ATTRIBUTE_KEYS,
      ...PORTAL_INFO_ATTRIBUTE_KEYS,
      SERVICO_ATTRIBUTE_KEY,
      ...TICKET_LINK_ATTRIBUTE_KEYS,
    ];

    expect(ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS).toEqual(expected);
    expect(new Set(ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS).size).toBe(
      ALL_CURATED_CONVERSATION_ATTRIBUTE_KEYS.length
    );
  });
});
