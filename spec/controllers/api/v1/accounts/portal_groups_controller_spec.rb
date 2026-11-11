require 'rails_helper'

# PATCH LOCAL (fork) - tela Grupos: cadastro guardado no Portal, repassado pelo Chatwoot.
RSpec.describe 'Portal Groups API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:portal_url) { 'http://portal.test/api/internal' }
  let(:portal_headers) { { 'X-Internal-Token' => 'segredo', 'X-Chatwoot-Account-Id' => account.id.to_s } }
  let(:base_path) { "/api/v1/accounts/#{account.id}/portal_groups" }
  let(:detail) do
    { 'id' => 3, 'name' => 'Clientes VIP', 'automatic' => false, 'active' => true,
      'empresas' => [{ 'id' => 1, 'nome' => 'Acme', 'cnpj' => '11222333000181', 'active' => true, 'contatos_count' => 2, 'recebem_count' => 1,
                       'contatos' => [{ 'id' => 9, 'name' => 'Ana', 'phone' => '+5511999990000', 'status' => 'recebe' },
                                      { 'id' => 10, 'name' => 'Beto', 'phone' => nil, 'status' => 'sem_telefone' }] }],
      'contatos' => [], 'recipients_count' => 2,
      'excluded' => { 'sem_telefone' => 0, 'sem_contato_no_chatwoot' => 1, 'inativos' => 0 } }
  end

  before do
    stub_const('ENV', ENV.to_h.merge('PORTAL_INTERNAL_API_URL' => 'http://portal.test', 'PORTAL_INTERNAL_API_TOKEN' => 'segredo'))
  end

  describe 'GET /api/v1/accounts/{account.id}/portal_groups' do
    it 'requires authentication' do
      get base_path, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists only the active Portal groups for any agent of the account' do
      groups = [{ 'id' => 'todos', 'name' => 'Todos os clientes ativos', 'automatic' => true, 'active' => true, 'empresas_count' => 5,
                  'contatos_count' => 12, 'recipients_count' => 9 }]
      stub = stub_request(:get, "#{portal_url}/client_groups").with(query: {}, headers: portal_headers)
                                                              .to_return(status: 200, body: { data: groups }.to_json)

      get base_path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['data']).to eq(groups)
      expect(stub).to have_been_requested
    end

    it 'asks the Portal for the inactive groups too when all=1, still for an agent' do
      stub = stub_request(:get, "#{portal_url}/client_groups").with(query: { all: 1 })
                                                              .to_return(status: 200, body: { data: [{ 'id' => 4, 'active' => false }] }.to_json)

      get base_path, params: { all: 1 }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['data']).to eq([{ 'id' => 4, 'active' => false }])
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
    it 'relays the group detail to any agent' do
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

    it 'answers 404 when the group does not exist in the Portal' do
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

  describe 'GET /api/v1/accounts/{account.id}/portal_groups/:id/recipients' do
    let(:recipients) do
      [{ 'chatwoot_contact_id' => 41, 'name' => 'Ana', 'phone' => '+5511999990000' },
       { 'chatwoot_contact_id' => 42, 'name' => 'Caio', 'phone' => '+5511999991111' }]
    end

    it 'relays who receives the automatic group to any agent' do
      stub = stub_request(:get, "#{portal_url}/client_groups/todos/recipients").with(headers: portal_headers)
                                                                               .to_return(status: 200, body: { data: recipients }.to_json)

      get "#{base_path}/todos/recipients", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['data']).to eq(recipients)
      expect(stub).to have_been_requested
    end

    it 'does not let an agent from another account see who receives' do
      other_agent = create(:user, account: create(:account), role: :agent)

      get "#{base_path}/todos/recipients", headers: other_agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'answers 502 when the Portal is down' do
      stub_request(:get, "#{portal_url}/client_groups/todos/recipients").to_timeout

      get "#{base_path}/todos/recipients", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:bad_gateway)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/portal_groups/options' do
    let(:options) do
      { 'empresas' => [{ 'id' => 1, 'nome' => 'Acme', 'cnpj' => '11222333000181', 'active' => true, 'contatos_count' => 1, 'recebem_count' => 1,
                         'contatos' => [{ 'id' => 9, 'name' => 'Ana', 'phone' => '+5511999990000', 'status' => 'recebe' }] }],
        'contatos' => [{ 'id' => 9, 'name' => 'Ana', 'email' => 'ana@acme.test', 'phone' => '+5511999990000', 'active' => true,
                         'empresas' => ['Acme'] }] }
    end

    it 'relays the companies and contacts that can join a group (and is not taken as a group id)' do
      stub = stub_request(:get, "#{portal_url}/client_groups/options").with(headers: portal_headers)
                                                                      .to_return(status: 200, body: options.to_json)

      get "#{base_path}/options", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq(options)
      expect(stub).to have_been_requested
    end

    it 'answers 502 when the Portal is down' do
      stub_request(:get, "#{portal_url}/client_groups/options").to_raise(Errno::ECONNRESET)

      get "#{base_path}/options", headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:bad_gateway)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/portal_groups' do
    it 'creates the group in the Portal for an administrator' do
      stub = stub_request(:post, "#{portal_url}/client_groups")
             .with(headers: portal_headers.merge('Content-Type' => 'application/json'),
                   body: { client_group: { name: 'Clientes VIP' } }.to_json)
             .to_return(status: 201, body: detail.to_json)

      post base_path, params: { client_group: { name: 'Clientes VIP', evil: 'x' } }, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq(detail)
      expect(stub).to have_been_requested
    end

    it 'does not let an agent create a group' do
      stub = stub_request(:post, "#{portal_url}/client_groups")

      post base_path, params: { client_group: { name: 'Clientes VIP' } }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(stub).not_to have_been_requested
    end

    it 'relays the Portal validation errors with 422' do
      stub_request(:post, "#{portal_url}/client_groups").to_return(status: 422, body: { errors: ['Nome já está em uso'] }.to_json)

      post base_path, params: { client_group: { name: 'Clientes VIP' } }, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['errors']).to eq(['Nome já está em uso'])
    end

    it 'answers 502 when the Portal is down' do
      stub_request(:post, "#{portal_url}/client_groups").to_raise(Errno::ECONNREFUSED)

      post base_path, params: { client_group: { name: 'Clientes VIP' } }, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:bad_gateway)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/portal_groups/:id' do
    it 'sends only the allowed fields and keeps an empty list as the complete (empty) list' do
      stub = stub_request(:patch, "#{portal_url}/client_groups/3")
             .with(headers: portal_headers.merge('Content-Type' => 'application/json'),
                   body: { client_group: { name: 'VIP', active: false, empresa_ids: [1, 2], partner_ids: [] } }.to_json)
             .to_return(status: 200, body: detail.merge('active' => false).to_json)

      patch "#{base_path}/3", headers: administrator.create_new_auth_token, as: :json,
                              params: { client_group: { name: 'VIP', active: false, empresa_ids: [1, 2], partner_ids: [], account_id: 99 } }

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['active']).to be false
      expect(stub).to have_been_requested
    end

    it 'does not touch the lists that were not sent' do
      stub = stub_request(:patch, "#{portal_url}/client_groups/3").with(body: { client_group: { active: true } }.to_json)
                                                                  .to_return(status: 200, body: detail.to_json)

      patch "#{base_path}/3", params: { client_group: { active: true } }, headers: administrator.create_new_auth_token, as: :json

      expect(stub).to have_been_requested
    end

    it 'does not let an agent update a group' do
      stub = stub_request(:patch, "#{portal_url}/client_groups/3")

      patch "#{base_path}/3", params: { client_group: { name: 'x' } }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(stub).not_to have_been_requested
    end

    it 'relays 404 when the group is not from the account or is the automatic one' do
      stub_request(:patch, "#{portal_url}/client_groups/todos").to_return(status: 404, body: '')

      patch "#{base_path}/todos", params: { client_group: { name: 'x' } }, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'relays the Portal validation errors with 422' do
      stub_request(:patch, "#{portal_url}/client_groups/3").to_return(status: 422, body: { errors: ['Nome não pode ficar em branco'] }.to_json)

      patch "#{base_path}/3", params: { client_group: { name: '' } }, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['errors']).to eq(['Nome não pode ficar em branco'])
    end

    it 'answers 502 when the Portal answers an error' do
      stub_request(:patch, "#{portal_url}/client_groups/3").to_return(status: 500, body: '')

      patch "#{base_path}/3", params: { client_group: { name: 'x' } }, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:bad_gateway)
    end
  end
end
