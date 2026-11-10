require 'rails_helper'

# PATCH LOCAL (fork) - tela Grupos (só leitura), repassada do Portal.
RSpec.describe 'Portal Groups API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:portal_url) { 'http://portal.test/api/internal' }
  let(:portal_headers) { { 'X-Internal-Token' => 'segredo', 'X-Chatwoot-Account-Id' => account.id.to_s } }
  let(:base_path) { "/api/v1/accounts/#{account.id}/portal_groups" }

  before do
    stub_const('ENV', ENV.to_h.merge('PORTAL_INTERNAL_API_URL' => 'http://portal.test', 'PORTAL_INTERNAL_API_TOKEN' => 'segredo'))
  end

  describe 'GET /api/v1/accounts/{account.id}/portal_groups' do
    it 'requires authentication' do
      get base_path, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists the Portal groups for any agent of the account' do
      groups = [{ 'id' => 'todos', 'name' => 'Todos os clientes ativos', 'automatic' => true, 'empresas_count' => 5,
                  'contatos_count' => 12, 'recipients_count' => 9 }]
      stub = stub_request(:get, "#{portal_url}/client_groups").with(headers: portal_headers)
                                                              .to_return(status: 200, body: { data: groups }.to_json)

      get base_path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['data']).to eq(groups)
      expect(stub).to have_been_requested
    end

    it 'does not let an agent from another account list the groups' do
      other_agent = create(:user, account: create(:account), role: :agent)

      get base_path, headers: other_agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'answers 502 with a friendly message when the Portal is down' do
      stub_request(:get, "#{portal_url}/client_groups").to_raise(Errno::ECONNREFUSED)

      get base_path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body['error']).to eq(I18n.t('portal_groups.portal_unavailable'))
    end

    it 'answers 502 when the Portal answers an error' do
      stub_request(:get, "#{portal_url}/client_groups").to_return(status: 500, body: '')

      get base_path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:bad_gateway)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/portal_groups/:id' do
    let(:detail) do
      { 'id' => 3, 'name' => 'Clientes VIP', 'automatic' => false,
        'empresas' => [{ 'id' => 1, 'nome' => 'Acme', 'active' => true, 'contatos_count' => 2 }],
        'contatos' => [], 'recipients_count' => 2,
        'excluded' => { 'sem_telefone' => 0, 'sem_contato_no_chatwoot' => 1, 'inativos' => 0 } }
    end

    it 'relays the group detail' do
      stub = stub_request(:get, "#{portal_url}/client_groups/3").with(headers: portal_headers)
                                                                .to_return(status: 200, body: detail.to_json)

      get "#{base_path}/3", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq(detail)
      expect(stub).to have_been_requested
    end

    it 'accepts the automatic group id' do
      stub = stub_request(:get, "#{portal_url}/client_groups/todos").to_return(status: 200, body: detail.merge('id' => 'todos').to_json)

      get "#{base_path}/todos", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(stub).to have_been_requested
    end

    it 'answers 404 when the group does not exist or is inactive in the Portal' do
      stub_request(:get, "#{portal_url}/client_groups/99").to_return(status: 404, body: '')

      get "#{base_path}/99", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']).to eq(I18n.t('portal_groups.not_found'))
    end

    it 'answers 502 when the Portal is down' do
      stub_request(:get, "#{portal_url}/client_groups/3").to_timeout

      get "#{base_path}/3", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:bad_gateway)
    end
  end
end
