require 'rails_helper'

RSpec.describe 'Internal tickets API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:team) { create(:team, account: account) }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    create(:team_member, team: team, user: agent)
  end

  def create_ticket(ticket, attachments: nil)
    post "/api/v1/accounts/#{account.id}/internal_tickets",
         headers: agent.create_new_auth_token, params: { ticket: ticket.to_json, attachments: attachments }.compact
  end

  it 'creates the ticket in one call' do
    create_ticket({
                    inbox_id: inbox.id, contact_id: contact.id, team_id: team.id, assignee_id: agent.id, priority: 'urgent',
                    custom_attributes: { assunto: 'Assunto', campos_adicionais: { checklist: %w[a b] } },
                    message: { content: 'Descrição', private: true }, watcher_ids: [agent.id]
                  })

    expect(response).to have_http_status(:success)
    ticket = account.conversations.find_by!(display_id: response.parsed_body['id'])
    expect(ticket).to have_attributes(team: team, assignee: agent, priority: 'urgent')
    expect(ticket.custom_attributes).to eq('assunto' => 'Assunto', 'campos_adicionais' => { 'checklist' => %w[a b] })
  end

  it 'stores the attachments of the first message' do
    file = fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')

    create_ticket({ inbox_id: inbox.id, contact_id: contact.id, message: { content: 'Com anexo' } }, attachments: [file])

    ticket = account.conversations.find_by!(display_id: response.parsed_body['id'])
    expect(ticket.messages.last.attachments.count).to eq(1)
  end

  it 'links the new ticket and announces it in the related conversation' do
    related = create(:conversation, account: account, inbox: inbox)

    create_ticket({ inbox_id: inbox.id, contact_id: contact.id, team_id: team.id,
                    link: { conversation_id: related.display_id, relation: 'parent', announce: true } })

    expect(related.reload.custom_attributes['ticket_pai_id']).to eq(response.parsed_body['id'].to_s)
    expect(related.messages.where(private: true).count).to eq(1)
  end

  it 'answers 422 and creates nothing when the input is invalid' do
    expect do
      create_ticket({ inbox_id: inbox.id, contact_id: contact.id, priority: 'whatever' })
    end.not_to change(Conversation, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('priority')
  end

  it 'refuses an inbox the agent cannot see' do
    hidden_inbox = create(:inbox, account: account)

    create_ticket({ inbox_id: hidden_inbox.id, contact_id: contact.id })

    expect(response).to have_http_status(:unauthorized)
  end
end
