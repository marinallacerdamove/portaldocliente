import { shouldOfferPortalTicket } from '../portalTicketOffer';

describe('shouldOfferPortalTicket', () => {
  const whatsapp = {
    meta: { channel: 'Channel::Whatsapp' },
    custom_attributes: {},
  };

  it('offers the question on a WhatsApp conversation that is not a ticket yet', () => {
    expect(shouldOfferPortalTicket(whatsapp)).toBe(true);
  });

  it('does not ask when the conversation already became a Portal ticket', () => {
    expect(
      shouldOfferPortalTicket({
        ...whatsapp,
        custom_attributes: { ticket_id: 5869 },
      })
    ).toBe(false);
  });

  it('does not ask on other channels or without conversation data', () => {
    expect(
      shouldOfferPortalTicket({
        meta: { channel: 'Channel::Api' },
        custom_attributes: {},
      })
    ).toBe(false);
    expect(
      shouldOfferPortalTicket({ meta: { channel: 'Channel::Email' } })
    ).toBe(false);
    expect(shouldOfferPortalTicket(undefined)).toBe(false);
  });
});
