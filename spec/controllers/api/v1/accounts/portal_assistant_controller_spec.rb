require 'rails_helper'

# Regressão B37 (auditoria 18/11): a resposta do Assistente era gerada dentro da requisição e o Chatwoot
# desiste em 12 s. O Portal agora responde em segundo plano; qualquer atendente consulta a própria pergunta.
RSpec.describe 'Portal assistant API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:client) { instance_double(PortalAssistant::Client) }

  before do
    allow(PortalAssistant::Client).to receive(:enabled_for?).and_return(true)
    allow(PortalAssistant::Client).to receive(:new).and_return(client)
  end

  it 'lets an agent read how their question is going' do
    allow(client).to receive(:request).with(:get, 'questions/42', {}).and_return([200, { 'id' => 42, 'pending' => true }])

    get "/api/v1/accounts/#{account.id}/portal_assistant/questions/42", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('id' => 42, 'pending' => true)
  end
end
