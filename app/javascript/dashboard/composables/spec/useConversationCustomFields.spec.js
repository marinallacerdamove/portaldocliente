import { conversationOrigin } from '../useConversationCustomFields';

describe('conversationOrigin', () => {
  const apiInbox = { name: 'Portal', channel_type: 'Channel::Api' };

  it('uses the channel type of the inbox by default', () => {
    expect(conversationOrigin(apiInbox)).toBe('cliente');
    expect(conversationOrigin({ channel_type: 'Channel::Email' })).toBe(
      'email'
    );
    expect(conversationOrigin(undefined)).toBe('');
  });

  it('is agente for the internal tickets inbox', () => {
    expect(
      conversationOrigin({
        name: 'Tickets Internos',
        channel_type: 'Channel::Api',
      })
    ).toBe('agente');
  });

  it('is agente when the Portal marks visivel_parceiro as false', () => {
    expect(conversationOrigin(apiInbox, { visivel_parceiro: false })).toBe(
      'agente'
    );
    expect(conversationOrigin(apiInbox, { visivel_parceiro: 'false' })).toBe(
      'agente'
    );
  });

  it('keeps the inbox rule when visivel_parceiro is true or missing', () => {
    expect(conversationOrigin(apiInbox, { visivel_parceiro: true })).toBe(
      'cliente'
    );
    expect(conversationOrigin(apiInbox, {})).toBe('cliente');
    expect(conversationOrigin(apiInbox, null)).toBe('cliente');
  });
});
