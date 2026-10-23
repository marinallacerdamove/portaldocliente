require 'rails_helper'

RSpec.describe 'Company Portal Updater Server API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:company) { create(:company, name: 'Acme', account: account) }
  let(:portal_url) { 'http://portal.test' }
  let(:portal_company_url) { "#{portal_url}/api/internal/companies/#{company.id}" }
  let(:portal_headers) { { 'X-Internal-Token' => 'segredo', 'X-Chatwoot-Account-Id' => account.id.to_s } }
  let(:base_path) { "/api/v1/accounts/#{account.id}/companies/#{company.id}/portal_update_server" }
  let(:payload) { { 'bases' => [], 'licenses' => [], 'modules' => [], 'summary' => { 'license_count' => 0 } } }

  before do
    account.enable_features!(:companies)
    stub_const('ENV', ENV.to_h.merge('PORTAL_INTERNAL_API_URL' => portal_url, 'PORTAL_INTERNAL_API_TOKEN' => 'segredo'))
  end

  describe 'GET portal_update_server' do
    it 'relays the Portal payload with the internal token and the account header' do
      stub = stub_request(:get, "#{portal_company_url}/update_server").with(headers: portal_headers)
                                                                      .to_return(status: 200, body: payload.to_json)

      get base_path, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq(payload)
      expect(stub).to have_been_requested
    end

    it 'relays 404 when the company is not linked to a Portal company' do
      stub_request(:get, "#{portal_company_url}/update_server").to_return(status: 404, body: '')

      get base_path, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'answers 502 with a friendly message when the Portal is down' do
      stub_request(:get, "#{portal_company_url}/update_server").to_raise(Errno::ECONNREFUSED)

      get base_path, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body['error']).to eq(I18n.t('portal_update_server.portal_unavailable'))
    end

    it 'requires authentication' do
      get base_path, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'sends the logged agent name to the Portal on reads, so the company history says who did it' do
      agent.update!(name: 'Ana Paula')
      stub = stub_request(:get, "#{portal_company_url}/update_server")
             .with(headers: portal_headers.merge('X-Chatwoot-User-Name' => 'Ana Paula'))
             .to_return(status: 200, body: payload.to_json)

      get base_path, headers: agent.create_new_auth_token, as: :json

      expect(stub).to have_been_requested
    end
  end

  describe 'writes' do
    it 'creates a base in the Portal sending only the allowed fields' do
      stub = stub_request(:post, "#{portal_company_url}/bases")
             .with(headers: portal_headers.merge('Content-Type' => 'application/json'),
                   body: { base: { albatross_id: 9001, display_name: 'BASE EXEMPLO', link: 'https://erp.test/9001' } }.to_json)
             .to_return(status: 201, body: payload.to_json)

      post "#{base_path}/bases", headers: admin.create_new_auth_token, as: :json,
                                 params: { base: { albatross_id: 9001, display_name: 'BASE EXEMPLO', link: 'https://erp.test/9001',
                                                   company_id: 999, evil: 'x' } }

      expect(response).to have_http_status(:created)
      expect(stub).to have_been_requested
    end

    it 'updates a base and relays the Portal validation errors' do
      stub_request(:patch, "#{portal_company_url}/bases/7")
        .to_return(status: 422, body: { errors: ['Link precisa começar com http:// ou https://'] }.to_json)

      patch "#{base_path}/bases/7", headers: admin.create_new_auth_token, as: :json,
                                    params: { base: { link: 'erp.test' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['errors'].first).to include('Link')
    end

    it 'creates and updates a license with its modules' do
      create_stub = stub_request(:post, "#{portal_company_url}/licenses")
                    .with(body: { license: { code: '5005', user_name: 'ana', license_module_ids: [1, 2] } }.to_json)
                    .to_return(status: 201, body: payload.to_json)
      update_stub = stub_request(:patch, "#{portal_company_url}/licenses/9")
                    .with(body: { license: { active: false } }.to_json)
                    .to_return(status: 200, body: payload.to_json)

      post "#{base_path}/licenses", headers: admin.create_new_auth_token, as: :json,
                                    params: { license: { code: '5005', user_name: 'ana', license_module_ids: [1, 2] } }
      patch "#{base_path}/licenses/9", headers: admin.create_new_auth_token, as: :json, params: { license: { active: false } }

      expect(create_stub).to have_been_requested
      expect(update_stub).to have_been_requested
    end

    it 'sends the logged agent name on writes, without line breaks' do
      admin.update!(name: "Jos\u00e9\r\nInjected: x")
      stub = stub_request(:patch, "#{portal_company_url}/bases/7")
             .with { |req| req.headers['X-Chatwoot-User-Name'] == "Jos\u00e9 Injected: x" }
             .to_return(status: 200, body: payload.to_json)

      patch "#{base_path}/bases/7", headers: admin.create_new_auth_token, as: :json, params: { base: { active: false } }

      expect(stub).to have_been_requested
    end

    it 'does not let an agent without company access change anything' do
      other_account_agent = create(:user, account: account, role: :agent)
      allow_any_instance_of(CompanyPolicy).to receive(:update?).and_return(false) # rubocop:disable RSpec/AnyInstance

      post "#{base_path}/bases", headers: other_account_agent.create_new_auth_token, as: :json, params: { base: { albatross_id: 1 } }

      expect(response).to have_http_status(:unauthorized).or have_http_status(:forbidden)
      expect(a_request(:post, "#{portal_company_url}/bases")).not_to have_been_made
    end
  end

  describe 'license modules' do
    it 'creates a module sending only the allowed fields' do
      stub = stub_request(:post, "#{portal_company_url}/license_modules")
             .with(headers: portal_headers.merge('Content-Type' => 'application/json'),
                   body: { license_module: { code: 'TSTX', name: 'Teste X' } }.to_json)
             .to_return(status: 201, body: { id: 1, code: 'TSTX' }.to_json)

      post "#{base_path}/license_modules", headers: admin.create_new_auth_token, as: :json,
                                           params: { license_module: { code: 'TSTX', name: 'Teste X', position: 5, evil: 'x' } }

      expect(response).to have_http_status(:created)
      expect(stub).to have_been_requested
    end

    it 'renames or deactivates a module and relays the Portal validation errors' do
      stub_request(:patch, "#{portal_company_url}/license_modules/3")
        .with(body: { license_module: { active: false } }.to_json).to_return(status: 200, body: { id: 3 }.to_json)
      stub_request(:patch, "#{portal_company_url}/license_modules/4")
        .to_return(status: 422, body: { errors: ['Código já está em uso'] }.to_json)

      patch "#{base_path}/license_modules/3", headers: admin.create_new_auth_token, as: :json, params: { license_module: { active: false } }
      expect(response).to have_http_status(:success)

      patch "#{base_path}/license_modules/4", headers: admin.create_new_auth_token, as: :json, params: { license_module: { code: 'DUP' } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['errors'].first).to include('Código')
    end

    it 'reorders the modules with integer ids' do
      stub = stub_request(:post, "#{portal_company_url}/license_modules/reorder")
             .with(body: { ids: [3, 1, 2] }.to_json).to_return(status: 200, body: '')

      post "#{base_path}/license_modules/reorder", headers: admin.create_new_auth_token, as: :json, params: { ids: %w[3 1 2] }

      expect(response).to have_http_status(:success)
      expect(stub).to have_been_requested
    end

    it 'does not let an agent without company access change the modules' do
      allow_any_instance_of(CompanyPolicy).to receive(:update?).and_return(false) # rubocop:disable RSpec/AnyInstance

      post "#{base_path}/license_modules", headers: agent.create_new_auth_token, as: :json, params: { license_module: { code: 'X' } }

      expect(response).to have_http_status(:unauthorized).or have_http_status(:forbidden)
      expect(a_request(:post, "#{portal_company_url}/license_modules")).not_to have_been_made
    end
  end

  describe 'Documents proxy keeps working after the shared relay change' do
    it 'still lists the files at the Portal files path' do
      stub = stub_request(:get, "#{portal_company_url}/files").with(headers: portal_headers)
                                                              .to_return(status: 200, body: { categories: [], files: [] }.to_json)

      get "/api/v1/accounts/#{account.id}/companies/#{company.id}/portal_documents", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(stub).to have_been_requested
    end
  end
end
