import {
  greeting,
  getPortalVariableValues,
  PORTAL_VARIABLES,
} from '../portalVariables';

describe('portalVariables', () => {
  it('greets by the time in Brasília, not the browser time zone', () => {
    // 11:59, 12:00 e 18:00 em Brasília (UTC-3).
    expect(greeting(new Date('2026-09-29T14:59:00Z'))).toBe('Bom dia');
    expect(greeting(new Date('2026-09-29T15:00:00Z'))).toBe('Boa tarde');
    expect(greeting(new Date('2026-09-29T21:00:00Z'))).toBe('Boa noite');
  });

  it('uses the Portal protocol as ticket number, falling back to the conversation', () => {
    const portalTicket = {
      id: 234,
      custom_attributes: {
        ticket_id_externo: '2026092510133',
        servico: 'Ticket Cancelado',
      },
    };
    expect(getPortalVariableValues(portalTicket)).toMatchObject({
      'ticket.numero': '2026092510133',
      'ticket.servico': 'Ticket Cancelado',
    });
    expect(
      getPortalVariableValues({ id: 99, custom_attributes: {} })[
        'ticket.numero'
      ]
    ).toBe(99);
  });

  it('has unique keys', () => {
    const keys = PORTAL_VARIABLES.map(variable => variable.key);
    expect(new Set(keys).size).toBe(keys.length);
  });
});
