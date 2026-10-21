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

  it 'sends a custom field created on the admin screen, with its key as the code' do
    post "/api/v1/accounts/#{account.id}/ticket_custom_fields", headers: admin.create_new_auth_token,
                                                                params: { ticket_custom_field: { name: 'Prazo do cliente', field_type: 'date' } }

    field = account.ticket_custom_fields.find_by!(key: 'prazo_do_cliente')
    expect_dispatch(field, TicketCatalog::SyncFields.fields('campo'))
    expect(TicketCatalog::WebhookPayload.new(field, []).as_json[:item]).to include(code: 'prazo_do_cliente')
  end

  it 'sends only the edited rule columns, with fields by key' do
    field = account.ticket_custom_fields.create!(name: 'Causa')
    rule = account.ticket_field_rules.create!(name: 'Regra', fields: [{ field_id: field.id }])

    patch "/api/v1/accounts/#{account.id}/ticket_field_rules/#{rule.id}", headers: admin.create_new_auth_token,
                                                                          params: { ticket_field_rule: { name: 'Regra nova' } }

    expect_dispatch(rule, %w[name])
    item = TicketCatalog::WebhookPayload.new(rule.reload, []).as_json[:item]
    expect(item[:fields].map { |entry| entry['field_key'] }).to eq(['causa'])
    expect(item[:fields].first).not_to have_key('field_id')
  end

  it 'does not send back what came from the Portal' do
    put "/api/v1/accounts/#{account.id}/ticket_catalog_sync/campo", headers: admin.create_new_auth_token,
                                                                    params: { code: 'causa', name: 'Causa', field_type: 'text', options: [] }, as: :json

    expect(response).to have_http_status(:success)
    expect(dispatcher).not_to have_received(:dispatch).with(Events::Types::TICKET_CATALOG_UPDATED, anything, anything)
  end

  it 'answers 422 for a rule whose field this account does not have yet' do
    put "/api/v1/accounts/#{account.id}/ticket_catalog_sync/regra", headers: admin.create_new_auth_token,
                                                                    params: { code: 'REG-0001', name: 'Espera', conditions: [],
                                                                              fields: [{ field_key: 'nao_existe' }] }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to include('nao_existe')
    expect(account.ticket_field_rules.count).to eq(0)
  end
end
