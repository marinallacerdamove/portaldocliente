require 'rails_helper'

RSpec.describe 'Ticket catalog sync API (Portal writes the catalog by code)', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/ticket_catalog_sync/#{catalog}" }
  let(:catalog) { 'tipo' }

  def put_sync(body, user: admin, path: url)
    put path, headers: user.create_new_auth_token, params: body, as: :json
  end

  describe 'lookup order' do
    it 'creates a new record and answers id, code and updated_at' do
      put_sync({ code: 'TIP-0001', name: 'Duvida', position: 2, allowed_priorities: %w[high low] })

      expect(response).to have_http_status(:success)
      record = account.ticket_categories.find_by!(code: 'TIP-0001')
      expect(response.parsed_body).to eq('id' => record.id, 'code' => 'TIP-0001', 'updated_at' => record.updated_at.iso8601(6))
      expect(record).to have_attributes(name: 'Duvida', position: 2, allowed_priorities: %w[high low])
    end

    it '1. finds the record by code and updates it (idempotent)' do
      record = account.ticket_categories.create!(name: 'Duvida')
      record.assign_code('TIP-0001')
      record.save!

      put_sync({ code: 'TIP-0001', name: 'Duvida geral', remote_id: 999_999 })
      updated_at = response.parsed_body['updated_at']
      put_sync({ code: 'TIP-0001', name: 'Duvida geral', remote_id: 999_999 })

      expect(account.ticket_categories.count).to eq(1)
      expect(record.reload.name).to eq('Duvida geral')
      expect(response.parsed_body).to include('id' => record.id, 'updated_at' => updated_at)
    end

    it '2. finds by remote_id when the record has no code yet and gives it the code' do
      record = account.ticket_categories.create!(name: 'Criado no Chatwoot')

      put_sync({ code: 'TIP-0007', name: 'Outro nome', remote_id: record.id })

      expect(response).to have_http_status(:success)
      expect(account.ticket_categories.count).to eq(1)
      expect(record.reload).to have_attributes(code: 'TIP-0007', name: 'Outro nome')
    end

    it 'ignores remote_id when the record already has another code' do
      other = account.ticket_categories.create!(name: 'Outro')
      other.assign_code('TIP-0001')
      other.save!

      put_sync({ code: 'TIP-0002', name: 'Novo', remote_id: other.id })

      expect(response).to have_http_status(:success)
      expect(other.reload).to have_attributes(code: 'TIP-0001', name: 'Outro')
      expect(account.ticket_categories.find_by!(code: 'TIP-0002').name).to eq('Novo')
    end

    it '3. finds by name (case insensitive) among records without code' do
      record = account.ticket_categories.create!(name: 'Duvida')

      put_sync({ code: 'TIP-0003', name: ' duvida ' })

      expect(response).to have_http_status(:success)
      expect(account.ticket_categories.count).to eq(1)
      expect(record.reload.code).to eq('TIP-0003')
    end

    it '3. by name in a service also matches the parent' do
      root = account.ticket_services.create!(name: 'Financeiro')
      root.assign_code('SRV-0001')
      root.save!
      other_root = account.ticket_services.create!(name: 'Comercial')
      loose = account.ticket_services.create!(name: 'Boletos', parent: other_root)

      put_sync({ code: 'SRV-0002', name: 'Boletos', parent_code: 'SRV-0001' }, path: "/api/v1/accounts/#{account.id}/ticket_catalog_sync/servico")

      expect(response).to have_http_status(:success)
      expect(loose.reload.code).to be_nil
      expect(account.ticket_services.find_by!(code: 'SRV-0002').parent).to eq(root)
    end

    it '4. does not touch other accounts' do
      other_account = create(:account)
      other = other_account.ticket_categories.create!(name: 'Duvida')

      put_sync({ code: 'TIP-0001', name: 'Duvida' })

      expect(response).to have_http_status(:success)
      expect(other.reload.code).to be_nil
      expect(account.ticket_categories.find_by!(code: 'TIP-0001')).not_to eq(other)
    end
  end

  describe 'conflicts and unknown references' do
    it '409 when the name is taken by a record with another code' do
      taken = account.ticket_categories.create!(name: 'Duvida')
      taken.assign_code('TIP-0001')
      taken.save!

      put_sync({ code: 'TIP-0002', name: 'Duvida' })

      expect(response).to have_http_status(:conflict)
      expect(account.ticket_categories.find_by(code: 'TIP-0002')).to be_nil
    end

    it '409 when renaming a record to a name another record owns' do
      account.ticket_categories.create!(name: 'Incidente')
      record = account.ticket_categories.create!(name: 'Duvida')
      record.assign_code('TIP-0001')
      record.save!

      put_sync({ code: 'TIP-0001', name: 'incidente' })

      expect(response).to have_http_status(:conflict)
      expect(record.reload.name).to eq('Duvida')
    end

    it '422 for an unknown parent_code and creates nothing' do
      put_sync({ code: 'SRV-0002', name: 'Boletos', parent_code: 'SRV-9999' }, path: "/api/v1/accounts/#{account.id}/ticket_catalog_sync/servico")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(account.ticket_services.count).to eq(0)
    end

    it '422 for an unknown category_codes entry and keeps the record unchanged' do
      known = account.ticket_categories.create!(name: 'Duvida')
      known.assign_code('TIP-0001')
      known.save!

      put_sync({ code: 'SRV-0002', name: 'Boletos', category_codes: %w[TIP-0001 TIP-9999] },
               path: "/api/v1/accounts/#{account.id}/ticket_catalog_sync/servico")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('TIP-9999')
      expect(account.ticket_services.count).to eq(0)
    end

    it '422 for an unknown default_category_code and for an unknown status code' do
      put_sync({ code: 'SRV-0002', name: 'Boletos', default_category_code: 'TIP-9999' },
               path: "/api/v1/accounts/#{account.id}/ticket_catalog_sync/servico")
      expect(response).to have_http_status(:unprocessable_entity)

      put_sync({ code: 'JUS-0001', name: 'Aguardando', status_codes: ['STS-9999'] },
               path: "/api/v1/accounts/#{account.id}/ticket_catalog_sync/justificativa")
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it '422 for a priority level that does not exist, for a missing code and for a bad code format' do
      put_sync({ code: 'TIP-0001', name: 'Duvida', allowed_priorities: %w[critical] })
      expect(response).to have_http_status(:unprocessable_entity)

      put_sync({ name: 'Sem codigo' })
      expect(response).to have_http_status(:unprocessable_entity)

      put_sync({ code: 'tip 1', name: 'Formato' })
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it '404 for a catalog that does not exist' do
      put_sync({ code: 'X-1', name: 'X' }, path: "/api/v1/accounts/#{account.id}/ticket_catalog_sync/prioridade")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'associations' do
    let(:catalog) { 'servico' }
    let!(:type_a) { account.ticket_categories.create!(name: 'A') }
    let!(:type_b) { account.ticket_categories.create!(name: 'B') }

    before do
      type_a.assign_code('TIP-0001')
      type_a.save!
      type_b.assign_code('TIP-0002')
      type_b.save!
    end

    it 'resolves parent, types and default type by code' do
      parent = account.ticket_services.create!(name: 'Financeiro')
      parent.assign_code('SRV-0001')
      parent.save!

      put_sync({ code: 'SRV-0002', name: 'Boletos', parent_code: 'SRV-0001', category_codes: %w[TIP-0002 TIP-0001],
                 default_category_code: 'TIP-0002', default_priority: 'high', all_categories: false })

      service = account.ticket_services.find_by!(code: 'SRV-0002')
      expect(service).to have_attributes(parent: parent, default_category: type_b, default_priority: 'high')
      expect(service.categories).to contain_exactly(type_a, type_b)
    end

    it 'clears parent and default type when the contract sends null, and empties the list with []' do
      parent = account.ticket_services.create!(name: 'Financeiro')
      service = account.ticket_services.create!(name: 'Boletos', parent: parent, default_category: type_a, categories: [type_a])
      service.assign_code('SRV-0002')
      service.save!

      put_sync({ code: 'SRV-0002', name: 'Boletos', parent_code: nil, default_category_code: nil, category_codes: [] })

      expect(service.reload).to have_attributes(parent: nil, default_category: nil)
      expect(service.categories).to be_empty
    end

    it 'renews updated_at when only the association changed' do
      service = account.ticket_services.create!(name: 'Boletos', categories: [type_a])
      service.assign_code('SRV-0002')
      service.save!
      before = service.reload.updated_at

      travel_to(1.hour.from_now) do
        put_sync({ code: 'SRV-0002', name: 'Boletos', category_codes: %w[TIP-0001 TIP-0002] })
      end

      expect(service.reload.updated_at).to be > before
      expect(service.categories).to contain_exactly(type_a, type_b)
    end

    it 'keeps updated_at when nothing changed' do
      service = account.ticket_services.create!(name: 'Boletos', categories: [type_a])
      service.assign_code('SRV-0002')
      service.save!
      before = service.reload.updated_at

      travel_to(1.hour.from_now) { put_sync({ code: 'SRV-0002', name: 'Boletos', category_codes: ['TIP-0001'] }) }

      expect(service.reload.updated_at).to eq(before)
    end
  end

  describe 'justification statuses' do
    it 'links the justification to statuses by code' do
      status = account.ticket_statuses.create!(name: 'Parado', base: 'parado')
      status.assign_code('STS-0003')
      status.save!

      put_sync({ code: 'JUS-0005', name: 'Aguardando', status_codes: ['STS-0003'] },
               path: "/api/v1/accounts/#{account.id}/ticket_catalog_sync/justificativa")

      expect(account.ticket_justifications.find_by!(code: 'JUS-0005').ticket_statuses).to contain_exactly(status)
    end
  end

  describe 'outbound webhook' do
    it 'does not dispatch ticket_catalog.updated for a write that came from the Portal' do
      allow(Rails.configuration.dispatcher).to receive(:dispatch).and_call_original

      put_sync({ code: 'TIP-0001', name: 'Duvida' })
      put_sync({ code: 'TIP-0001', name: 'Duvida 2' })

      expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(Events::Types::TICKET_CATALOG_UPDATED, any_args)
    end
  end

  describe 'authorization' do
    it 'refuses an agent' do
      put_sync({ code: 'TIP-0001', name: 'Duvida' }, user: agent)

      expect(response).to have_http_status(:unauthorized)
      expect(account.ticket_categories.count).to eq(0)
    end

    it 'refuses an administrator of another account' do
      other_admin = create(:user, account: create(:account), role: :administrator)

      put_sync({ code: 'TIP-0001', name: 'Duvida' }, user: other_admin)

      expect(response).to have_http_status(:unauthorized)
      expect(account.ticket_categories.count).to eq(0)
    end

    it 'refuses without credentials' do
      put url, params: { code: 'TIP-0001', name: 'Duvida' }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'accepts an administrator authenticated by access token (how the Portal calls)' do
      put url, headers: { api_access_token: admin.access_token.token }, params: { code: 'TIP-0001', name: 'Duvida' }, as: :json

      expect(response).to have_http_status(:success)
    end
  end
end
