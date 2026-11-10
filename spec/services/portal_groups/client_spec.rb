require 'rails_helper'

# PATCH LOCAL (fork) - consulta dos Grupos de clientes no Portal.
describe PortalGroups::Client do
  let(:account) { create(:account) }
  let(:client) { described_class.new(account: account) }
  let(:portal_url) { 'http://portal.test/api/internal' }
  let(:portal_headers) { { 'X-Internal-Token' => 'segredo', 'X-Chatwoot-Account-Id' => account.id.to_s } }

  around do |example|
    with_modified_env(PORTAL_INTERNAL_API_URL: 'http://portal.test', PORTAL_INTERNAL_API_TOKEN: 'segredo') { example.run }
  end

  describe '#list' do
    it 'asks only the active groups by default and sends no user name when there is no logged user' do
      stub = stub_request(:get, "#{portal_url}/client_groups").with(query: {}) { |request| request.headers.keys.exclude?('X-Chatwoot-User-Name') }
                                                              .to_return(status: 200, body: { data: [] }.to_json)

      client.list

      expect(stub).to have_been_requested
    end

    it 'asks the inactive groups too with all: true' do
      stub = stub_request(:get, "#{portal_url}/client_groups").with(query: { all: 1 }, headers: portal_headers)
                                                              .to_return(status: 200, body: { data: [{ 'id' => 4, 'active' => false }] }.to_json)

      expect(client.list(all: true)).to eq([{ 'id' => 4, 'active' => false }])
      expect(stub).to have_been_requested
    end

    it 'returns the groups with the internal token and the account header' do
      groups = [{ 'id' => 'todos', 'name' => 'Todos os clientes ativos', 'automatic' => true, 'recipients_count' => 10 }]
      stub = stub_request(:get, "#{portal_url}/client_groups").with(headers: portal_headers)
                                                              .to_return(status: 200, body: { data: groups }.to_json)

      expect(client.list).to eq(groups)
      expect(stub).to have_been_requested
    end
  end

  describe '#show' do
    it 'returns the group detail' do
      detail = { 'id' => 3, 'name' => 'Clientes VIP', 'automatic' => false, 'recipients_count' => 4 }
      stub_request(:get, "#{portal_url}/client_groups/3").with(headers: portal_headers).to_return(status: 200, body: detail.to_json)

      expect(client.show(3)).to eq(detail)
    end

    it 'does not let the id escape the groups path' do
      stub = stub_request(:get, "#{portal_url}/client_groups/..%2F..%2Fcompanies").to_return(status: 404, body: '')

      expect { client.show('../../companies') }.to raise_error(described_class::Error)
      expect(stub).to have_been_requested
    end

    it 'raises an error carrying the HTTP status when the Portal answers 404' do
      stub_request(:get, "#{portal_url}/client_groups/99").to_return(status: 404, body: '')

      expect { client.show(99) }.to raise_error(described_class::Error) { |error| expect(error.status).to eq(404) }
    end
  end

  describe '#options' do
    it 'returns the companies and contacts that can join a group' do
      options = { 'empresas' => [{ 'id' => 1, 'nome' => 'Acme', 'cnpj' => '11222333000181', 'active' => true, 'contatos_count' => 2,
                                   'recebem_count' => 1,
                                   'contatos' => [{ 'id' => 9, 'name' => 'Ana', 'phone' => '+5511999990000', 'status' => 'recebe' },
                                                  { 'id' => 10, 'name' => 'Beto', 'phone' => nil, 'status' => 'sem_telefone' }] }],
                  'contatos' => [{ 'id' => 9, 'name' => 'Ana', 'email' => 'ana@acme.test', 'phone' => '+5511999990000', 'active' => true,
                                   'empresas' => ['Acme'] }] }
      stub = stub_request(:get, "#{portal_url}/client_groups/options").with(headers: portal_headers)
                                                                      .to_return(status: 200, body: options.to_json)

      expect(client.options).to eq(options)
      expect(stub).to have_been_requested
    end
  end

  describe '#create' do
    it 'posts the group name as JSON and returns the detail' do
      detail = { 'id' => 5, 'name' => 'Clientes VIP', 'active' => true }
      stub = stub_request(:post, "#{portal_url}/client_groups")
             .with(headers: portal_headers.merge('Content-Type' => 'application/json'), body: { client_group: { name: 'Clientes VIP' } }.to_json)
             .to_return(status: 201, body: detail.to_json)

      expect(client.create(name: 'Clientes VIP')).to eq(detail)
      expect(stub).to have_been_requested
    end

    it 'raises an error with the Portal messages on a 422' do
      stub_request(:post, "#{portal_url}/client_groups").to_return(status: 422, body: { errors: ['Nome já está em uso'] }.to_json)

      expect { client.create(name: 'Clientes VIP') }.to raise_error(described_class::Error) do |error|
        expect(error.status).to eq(422)
        expect(error.errors).to eq(['Nome já está em uso'])
      end
    end

    it 'keeps errors empty when a 422 body is not the expected JSON' do
      stub_request(:post, "#{portal_url}/client_groups").to_return(status: 422, body: 'oops')

      expect { client.create(name: '') }.to raise_error(described_class::Error) { |error| expect(error.errors).to be_nil }
    end
  end

  describe '#update' do
    it 'patches the complete lists and returns the detail' do
      attributes = { name: 'VIP', active: false, empresa_ids: [1, 2], partner_ids: [] }
      stub = stub_request(:patch, "#{portal_url}/client_groups/5")
             .with(headers: portal_headers.merge('Content-Type' => 'application/json'), body: { client_group: attributes }.to_json)
             .to_return(status: 200, body: { 'id' => 5, 'active' => false }.to_json)

      expect(client.update(5, attributes)).to eq('id' => 5, 'active' => false)
      expect(stub).to have_been_requested
    end

    it 'raises an error with the status when the group is not from the account or is the automatic one' do
      stub_request(:patch, "#{portal_url}/client_groups/todos").to_return(status: 404, body: '')

      expect { client.update('todos', name: 'x') }.to raise_error(described_class::Error) { |error| expect(error.status).to eq(404) }
    end
  end

  describe 'agent name header' do
    it 'sends the logged agent name without line breaks, so the Portal history says who changed' do
      user = create(:user, account: account, name: "Jos\u00e9\r\nInjected: x")
      stub = stub_request(:patch, "#{portal_url}/client_groups/5")
             .with(headers: portal_headers.merge('X-Chatwoot-User-Name' => 'José Injected: x'))
             .to_return(status: 200, body: '{}')

      described_class.new(account: account, user: user).update(5, name: 'x')

      expect(stub).to have_been_requested
    end
  end

  describe '#recipients' do
    it 'returns the contacts that receive now' do
      recipients = [{ 'chatwoot_contact_id' => 7, 'name' => 'Ana', 'phone' => '+5511999990000' }]
      stub = stub_request(:get, "#{portal_url}/client_groups/todos/recipients").with(headers: portal_headers)
                                                                               .to_return(status: 200, body: { data: recipients }.to_json)

      expect(client.recipients('todos')).to eq(recipients)
      expect(stub).to have_been_requested
    end
  end

  describe 'errors' do
    it 'turns a non-2xx answer into Client::Error with a useful message' do
      stub_request(:get, "#{portal_url}/client_groups").to_return(status: 401, body: '')

      expect { client.list }.to raise_error(described_class::Error, /HTTP 401 em client_groups/) { |error| expect(error.status).to eq(401) }
    end

    it 'turns network failures into Client::Error' do
      stub_request(:get, "#{portal_url}/client_groups").to_raise(Errno::ECONNREFUSED)

      expect { client.list }.to raise_error(described_class::Error, /ECONNREFUSED/)
    end

    it 'turns timeouts into Client::Error' do
      stub_request(:get, "#{portal_url}/client_groups").to_timeout

      expect { client.list }.to raise_error(described_class::Error)
    end

    it 'turns a body that is not JSON into Client::Error' do
      stub_request(:get, "#{portal_url}/client_groups").to_return(status: 200, body: '<html>bad gateway</html>')

      expect { client.list }.to raise_error(described_class::Error, /resposta inválida/)
    end
  end
end
