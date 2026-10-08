require 'rails_helper'

# Mesmo arquivo lido por constants/specs/ticketContract.spec.js: mudar uma chave
# de um lado só quebra um dos dois.
RSpec.describe TicketContract do
  let(:fixture) { JSON.parse(Rails.root.join('spec/fixtures/fork_parity/ticket_contract.json').read) }

  it 'declares the custom attribute keys shared with the frontend' do
    keys = described_class.constants.grep(/_KEY\z/).to_h { |name| [name.to_s, described_class.const_get(name)] }

    expect(keys).to eq(fixture['attribute_keys'])
  end

  it 'names the internal tickets inbox like the frontend' do
    expect(described_class::INTERNAL_TICKETS_INBOX_NAME).to eq(fixture['internal_tickets_inbox_name'])
  end

  it 'maps channel origins like the frontend (conversationOrigin)' do
    expect(Conversations::ResolveRequirementsService::CHANNEL_ORIGINS).to eq(fixture['channel_origins'])
  end
end
