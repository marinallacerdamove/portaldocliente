require 'rails_helper'

# Regressão B85 (auditoria 18/11): os clientes do Portal (Assistente, Contatos, Documentos/Updater
# Server) só tratavam timeout, conexão recusada/derrubada e DNS. Host inalcançável, erro de TLS ou
# resposta HTTP quebrada escapavam como 500 em vez do erro do cliente (que a tela mostra como 502).
RSpec.describe PortalNetworkErrors do
  let(:account) { create(:account) }
  let(:failures) { [Errno::EHOSTUNREACH.new, OpenSSL::SSL::SSLError.new('ssl'), Net::HTTPBadResponse.new('bad')] }

  around { |example| with_modified_env(PORTAL_INTERNAL_API_URL: 'http://portal.test', PORTAL_INTERNAL_API_TOKEN: 'x') { example.run } }

  it 'Assistente' do
    failures.each do |failure|
      allow(HTTParty).to receive(:send).and_raise(failure)
      client = PortalAssistant::Client.new(account: account, user: create(:user, account: account))
      expect { client.request(:get, 'areas') }.to raise_error(PortalAssistant::Client::Error)
    end
  end

  it 'Contatos' do
    failures.each do |failure|
      allow(HTTParty).to receive(:post).and_raise(failure)
      client = PortalContacts::Client.new(account: account)
      contact = create(:contact, account: account)
      conversation = create(:conversation, account: account)
      expect { client.register(contact: contact, conversation: conversation, name: 'A', email: 'a@a.com', phone: nil) }
        .to raise_error(PortalContacts::Client::Error)
    end
  end

  it 'Documentos' do
    failures.each do |failure|
      allow(HTTParty).to receive(:send).and_raise(failure)
      client = PortalDocuments::Client.new(account: account, company: create(:company, account: account))
      expect { client.list }.to raise_error(PortalDocuments::Client::Error)
    end
  end
end
