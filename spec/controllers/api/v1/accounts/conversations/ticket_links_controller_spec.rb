require 'rails_helper'

RSpec.describe 'Conversation ticket link API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account) }
  let(:other) { create(:conversation, account: account, inbox: conversation.inbox) }

  before { create(:inbox_member, user: agent, inbox: conversation.inbox) }

  def link(relation, ticket_id)
    post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/ticket_link",
         headers: agent.create_new_auth_token, params: { relation: relation, ticket_id: ticket_id }, as: :json
  end

  it 'links an existing ticket as child' do
    link('child', other.display_id)

    expect(response).to have_http_status(:success)
    expect(other.reload.custom_attributes['ticket_pai_id']).to eq(conversation.display_id.to_s)
    ids = response.parsed_body['payload'].pluck('id')
    expect(ids).to contain_exactly(conversation.display_id, other.display_id)
  end

  it 'links an existing ticket as parent' do
    link('parent', other.display_id)

    expect(conversation.reload.custom_attributes['ticket_pai_id']).to eq(other.display_id.to_s)
    expect(other.reload.custom_attributes['ticket_filhos_ids']).to eq(conversation.display_id.to_s)
  end

  it 'returns the reason when the link makes a cycle' do
    link('child', other.display_id)
    link('parent', other.display_id)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('cycle')
  end

  it 'refuses a ticket the agent cannot see' do
    hidden = create(:conversation, account: account)

    link('child', hidden.display_id)

    expect(response).to have_http_status(:unauthorized)
    expect(hidden.reload.custom_attributes).not_to have_key('ticket_pai_id')
  end
end
