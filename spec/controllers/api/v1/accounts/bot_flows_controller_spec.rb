require 'rails_helper'

RSpec.describe 'Bot flows API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  it 'answers 404 for an id that does not exist in the account' do
    other_flow = create(:account).bot_flows.create!(name: 'Outro', nodes: [{ 'id' => 'start', 'type' => 'start' }])

    [other_flow.id, 0].each do |id|
      get "/api/v1/accounts/#{account.id}/bot_flows/#{id}", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)

      patch "/api/v1/accounts/#{account.id}/bot_flows/#{id}", params: { name: 'x' }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)

      delete "/api/v1/accounts/#{account.id}/bot_flows/#{id}", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
