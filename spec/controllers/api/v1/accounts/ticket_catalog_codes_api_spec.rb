require 'rails_helper'

RSpec.describe 'Ticket catalog API and business code', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  {
    'ticket_services' => [TicketService, :ticket_services, {}],
    'ticket_categories' => [TicketCategory, :ticket_categories, {}],
    'ticket_statuses' => [TicketStatus, :ticket_statuses, { base: 'novo' }],
    'ticket_justifications' => [TicketJustification, :ticket_justifications, {}],
    'ticket_close_reasons' => [TicketCloseReason, :ticket_close_reasons, {}]
  }.each do |path, (model, association, extra)|
    describe "/#{path}" do
      let(:param_key) { model.model_name.singular }
      let(:url) { "/api/v1/accounts/#{account.id}/#{path}" }

      it 'ignores a code sent on create and returns code null' do
        post url, headers: admin.create_new_auth_token, params: { param_key => { name: 'Novo item', code: 'SRV-0001', **extra } }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to include('name' => 'Novo item', 'code' => nil)
        expect(account.public_send(association).find_by!(name: 'Novo item').code).to be_nil
      end

      it 'ignores a code sent on update and keeps the one the Portal gave' do
        item = account.public_send(association).create!(name: 'Item', **extra)
        item.assign_code('SRV-0007')
        item.save!

        patch "#{url}/#{item.id}", headers: admin.create_new_auth_token, params: { param_key => { name: 'Item renomeado', code: 'SRV-9999' } }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to include('name' => 'Item renomeado', 'code' => 'SRV-0007')
      end

      it 'exposes the code to agents in the list' do
        item = account.public_send(association).create!(name: 'Item', **extra)
        item.assign_code('SRV-0007')
        item.save!

        get url, headers: agent.create_new_auth_token

        expect(response.parsed_body['payload'].pluck('code')).to eq(['SRV-0007'])
      end

      it 'rejects a case-insensitive duplicate name' do
        account.public_send(association).create!(name: 'Item', **extra)

        post url, headers: admin.create_new_auth_token, params: { param_key => { name: 'ITEM', **extra } }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
