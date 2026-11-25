import {
  agentEditor,
  conversationOrigin,
} from '../useConversationCustomFields';

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

describe('agentEditor', () => {
  const teams = [
    { id: 1, name: 'tecnologia e infraestrutura' },
    { id: 2, name: 'suporte' },
  ];
  const agents = [
    { id: 7, team_ids: [1] },
    { id: 8, team_ids: [] },
  ];

  it('lists the team names of the current agent', () => {
    expect(
      agentEditor({ isAdmin: false, currentUserId: 7, agents, teams })
    ).toEqual({ isAdmin: false, teamNames: ['tecnologia e infraestrutura'] });
  });

  it('has no team while the agent list is not loaded or he has none', () => {
    expect(
      agentEditor({ isAdmin: true, currentUserId: 8, agents, teams })
    ).toEqual({ isAdmin: true, teamNames: [] });
    expect(
      agentEditor({ isAdmin: false, currentUserId: 7, agents: [], teams })
    ).toEqual({ isAdmin: false, teamNames: [] });
  });
});
