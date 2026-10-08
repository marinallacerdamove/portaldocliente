require 'rails_helper'

RSpec.describe TicketStatus do
  let(:account) { create(:account) }

  it 'exposes the native conversation status of its base' do
    status = account.ticket_statuses.create!(name: 'Em atendimento', base: 'em_atendimento')

    expect(status.as_json).to include('conversation_status' => 'open')
  end

  it 'lists the statuses that resolve the conversation' do
    account.ticket_statuses.create!(name: 'Novo', base: 'novo')
    closed = account.ticket_statuses.create!(name: 'Fechado', base: 'fechado')
    cancelled = account.ticket_statuses.create!(name: 'Cancelado', base: 'cancelado')

    expect(account.ticket_statuses.resolving).to contain_exactly(closed, cancelled)
  end
end
