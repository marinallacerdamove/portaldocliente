require 'rails_helper'

RSpec.describe 'Ticket catalog admin screen and the Portal event', type: :request do
  let(:account) { create(:account) }
  let(:dispatcher) { Rails.configuration.dispatcher }
  let(:admin) { create(:user, account: account, role: :administrator) }

  before { allow(dispatcher).to receive(:dispatch).and_call_original }

  def expect_dispatch(item, keys)
    expect(dispatcher).to have_received(:dispatch).with(Events::Types::TICKET_CATALOG_UPDATED, anything, item: item, changed_keys: keys).once
  end

  it 'sends category_codes and renews updated_at when only the type list changed' do
    type = account.ticket_categories.create!(name: 'A')
    service = account.ticket_services.create!(name: 'Boletos')
    before = service.updated_at

    travel_to(1.hour.from_now) do
      patch "/api/v1/accounts/#{account.id}/ticket_services/#{service.id}", headers: admin.create_new_auth_token,
                                                                            params: { ticket_service: { category_ids: [type.id] } }
    end

    expect(response).to have_http_status(:success)
    expect(service.reload.updated_at).to be > before
    expect_dispatch(service, %w[category_codes])
  end

  it 'sends status_codes when the justification statuses changed' do
    status = account.ticket_statuses.create!(name: 'Parado', base: 'parado')
    justification = account.ticket_justifications.create!(name: 'Aguardando')

    patch "/api/v1/accounts/#{account.id}/ticket_justifications/#{justification.id}", headers: admin.create_new_auth_token,
                                                                                      params: { ticket_justification: { status_ids: [status.id] } }

    expect_dispatch(justification, %w[status_codes])
  end

  it 'does not dispatch when the list sent is the same as the current one' do
    type = account.ticket_categories.create!(name: 'A')
    service = account.ticket_services.create!(name: 'Boletos', categories: [type])
    patch "/api/v1/accounts/#{account.id}/ticket_services/#{service.id}", headers: admin.create_new_auth_token,
                                                                          params: { ticket_service: { category_ids: [type.id] } }

    expect(dispatcher).to have_received(:dispatch).with(Events::Types::TICKET_CATALOG_UPDATED, anything, hash_including(item: service)).once
  end
end
