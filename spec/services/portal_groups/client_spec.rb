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
