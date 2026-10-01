require 'rails_helper'

RSpec.describe Conversations::ChecklistActivityService do
  let(:account) { create(:account) }
  let!(:field) { TicketCustomField.create!(account: account, name: 'Checklist: 1 - Atualização', field_type: 'checklist', options: %w[A B C]) }
  let(:agent) { create(:user, account: account, role: :agent, name: 'Marina') }
  let(:conversation) { create(:conversation, account: account, custom_attributes: { 'campos_adicionais' => { field.key => %w[A B] } }) }

  before { create(:inbox_member, user: agent, inbox: conversation.inbox) }

  def post_attributes(values, headers:, **extra)
    post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/custom_attributes",
         headers: headers, params: { custom_attributes: { 'campos_adicionais' => { field.key => values } } }.merge(extra), as: :json
  end

  it 'grava a atividade com quem marcou e desmarcou, pela tela', type: :request do
    post_attributes(%w[A C], headers: agent.create_new_auth_token)

    activity = conversation.messages.activity.last
    expect(activity.content).to eq('Marina em Checklist: 1 - Atualização, marcou: C e desmarcou: B')
    expect(activity.content_attributes['checklist']).to include('source' => 'chatwoot', 'marked' => ['C'], 'unmarked' => ['B'])
  end

  it 'pela integração usa o nome que o Portal manda, e sem nome não grava', type: :request do
    admin = create(:user, account: account, role: :administrator)
    with_modified_env PORTAL_INTEGRATION_USER_EMAIL: admin.email do
      post_attributes(%w[A], headers: { api_access_token: admin.access_token.token }, actor_name: 'Fulano do Portal')
      expect(conversation.messages.activity.last.content).to start_with('Fulano do Portal em')
      expect(conversation.messages.activity.last.content_attributes.dig('checklist', 'source')).to eq('portal')

      expect { post_attributes(%w[A B], headers: { api_access_token: admin.access_token.token }) }
        .not_to(change { conversation.messages.activity.count })
    end
  end

  it 'campo que não é checklist não gera atividade', type: :request do
    other = TicketCustomField.create!(account: account, name: 'Classificação', field_type: 'list', options: %w[X])
    expect do
      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/custom_attributes",
           headers: agent.create_new_auth_token, as: :json,
           params: { custom_attributes: { 'campos_adicionais' => { field.key => %w[A B], other.key => 'X' } } }
    end.not_to(change { conversation.messages.activity.count })
  end
end
