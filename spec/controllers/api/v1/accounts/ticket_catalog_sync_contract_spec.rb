require 'rails_helper'

# Mesmo arquivo de exemplos roda no Portal (Integration::CatalogSync): o que o
# Portal manda, o fork entende; o que o fork emite, o Portal le.
CATALOG_SYNC_CONTRACT = JSON.parse(Rails.root.join('spec/fixtures/fork_parity/ticket_catalog_sync_contract.json').read).freeze

RSpec.describe 'Ticket catalog sync contract with the Portal', type: :request do
  let(:contract) { CATALOG_SYNC_CONTRACT }
  let(:account) { create(:account, id: contract['account']['id'], name: contract['account']['name']) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:fixed_time) { Time.iso8601(contract['fixed_updated_at']) }

  def catalog_scope(catalog)
    account.public_send(TicketCatalog::SyncFields::CATALOGS.fetch(catalog)[:association])
  end

  def create_existing(items)
    items.each do |entry|
      item = catalog_scope(entry['catalog']).create!(name: entry['name'], **entry.slice('base').symbolize_keys)
      next unless entry['code']

      item.assign_code(entry['code'])
      item.save!
    end
  end

  it 'covers every catalog in both directions' do
    catalogs = TicketCatalog::SyncFields::CATALOGS.keys

    expect(contract['put_requests'].pluck('catalog')).to match_array(catalogs)
    expect(contract['webhooks'].map { |example| example.dig('record', 'catalog') }).to match_array(catalogs)
  end

  describe 'Portal -> fork (PUT bodies)' do
    CATALOG_SYNC_CONTRACT['put_requests'].each do |example|
      context example['name'] do
        let(:path) { "/api/v1/accounts/#{account.id}/ticket_catalog_sync/#{example['catalog']}" }

        before { create_existing(example['existing']) }

        it 'accepts the body, answers id/code/updated_at and stores the expected item' do
          travel_to(fixed_time, with_usec: true) { put path, headers: admin.create_new_auth_token, params: example['request'], as: :json }

          expect(response).to have_http_status(:success), response.body
          expect(response.parsed_body.keys).to match_array(%w[id code updated_at])
          expect(response.parsed_body).to include('code' => example['request']['code'], 'updated_at' => contract['fixed_updated_at'])
          record = catalog_scope(example['catalog']).find(response.parsed_body['id'])
          item = TicketCatalog::WebhookPayload.new(record, []).as_json[:item].except(:id)
          expect(JSON.parse(item.to_json)).to eq(example['expected_item'])
        end

        it 'is idempotent: the same body again answers the same and changes nothing' do
          travel_to(fixed_time, with_usec: true) { put path, headers: admin.create_new_auth_token, params: example['request'], as: :json }
          first = response.parsed_body
          travel_to(fixed_time + 1.hour, with_usec: true) { put path, headers: admin.create_new_auth_token, params: example['request'], as: :json }

          expect(response.parsed_body).to eq(first)
          expect(catalog_scope(example['catalog']).where(code: example['request']['code']).count).to eq(1)
        end
      end
    end
  end

  describe 'fork -> Portal (webhook bodies)' do
    def build_record(example)
      create_existing(example['existing'])
      spec = example['record']
      record = TicketCatalog::SyncFields::CATALOGS.fetch(spec['catalog'])[:model].constantize.new(account: account, id: spec['id'])
      TicketCatalog::SyncFields::COLUMNS.fetch(spec['catalog']).each { |column| record[column] = spec[column] if spec.key?(column) }
      assign_references(record, spec)
      record.assign_code(spec['code'])
      record.save!
      record
    end

    def assign_references(record, spec)
      record.parent = account.ticket_services.find_by!(code: spec['parent_code']) if spec['parent_code']
      record.default_category = account.ticket_categories.find_by!(code: spec['default_category_code']) if spec['default_category_code']
      assign_lists(record, spec)
    end

    def assign_lists(record, spec)
      record.categories = account.ticket_categories.where(code: spec['category_codes']).to_a if spec['category_codes']
      record.ticket_statuses = account.ticket_statuses.where(code: spec['status_codes']).to_a if spec['status_codes']
    end

    CATALOG_SYNC_CONTRACT['webhooks'].each do |example|
      it "builds the body the Portal handler parses: #{example['name']}" do
        record = nil
        travel_to(fixed_time, with_usec: true) { record = build_record(example) }

        payload = TicketCatalog::WebhookPayload.new(record, example['changed_keys']).as_json

        expect(JSON.parse(payload.to_json)).to eq(example['expected'])
        expect(example['changed_keys'] - TicketCatalog::SyncFields.fields(example.dig('record', 'catalog'))).to be_empty
      end
    end
  end
end
