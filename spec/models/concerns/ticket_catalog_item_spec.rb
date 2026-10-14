require 'rails_helper'

RSpec.describe TicketCatalogItem do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }

  {
    TicketService => :ticket_services,
    TicketCategory => :ticket_categories,
    TicketStatus => :ticket_statuses,
    TicketJustification => :ticket_justifications,
    TicketCloseReason => :ticket_close_reasons
  }.each do |model, association|
    describe model.name do
      let(:attributes) { model == TicketStatus ? { base: 'novo' } : {} }
      let(:item) { account.public_send(association).create!(name: 'Item A', **attributes) }

      it 'starts without code, which keeps the record valid' do
        expect(item.code).to be_nil
        expect(item.as_json).to include('code' => nil)
      end

      it 'accepts a code once, through assign_code' do
        item.assign_code('SRV-0042')
        item.save!

        expect(item.reload.code).to eq('SRV-0042')
        expect(item.as_json).to include('code' => 'SRV-0042')
      end

      it 'never changes a code that is already set' do
        item.assign_code('SRV-0042')
        item.save!
        item.assign_code('SRV-0043')

        expect(item).not_to be_valid
        expect(item.errors[:code]).to be_present
        expect(item.reload.code).to eq('SRV-0042')
      end

      it 'does not let the code be removed once set' do
        item.assign_code('SRV-0042')
        item.save!
        item.assign_code(nil)

        expect(item).not_to be_valid
      end

      it 'is not mass-assignable' do
        expect { account.public_send(association).new(name: 'X', code: 'SRV-0001', **attributes) }.to raise_error(ActiveModel::UnknownAttributeError)
        expect { item.update(code: 'SRV-0001') }.to raise_error(ActiveModel::UnknownAttributeError)
      end

      it 'rejects malformed codes' do
        item.assign_code('srv 42')

        expect(item).not_to be_valid
      end

      it 'keeps the code unique within the account only' do
        item.assign_code('SRV-0042')
        item.save!
        twin = account.public_send(association).new(name: 'Item B', **attributes)
        twin.assign_code('SRV-0042')
        foreign = other_account.public_send(association).new(name: 'Item A', **attributes)
        foreign.assign_code('SRV-0042')

        expect(twin).not_to be_valid
        expect(foreign).to be_valid
      end

      it 'allows many items without code in the same account' do
        item
        expect(account.public_send(association).new(name: 'Item B', **attributes)).to be_valid
      end

      it 'rejects names that differ only by case, in the same account' do
        item

        expect(account.public_send(association).new(name: 'item a', **attributes)).not_to be_valid
        expect(other_account.public_send(association).new(name: 'item a', **attributes)).to be_valid
      end

      it 'keeps saving other fields of legacy records whose names differ only by case' do
        item
        legacy = account.public_send(association).new(name: 'ITEM A', **attributes)
        legacy.save!(validate: false)

        expect(legacy.reload.update(active: false)).to be(true)
      end
    end
  end

  it 'allows the same service name under different parents but not under the same one' do
    parent = account.ticket_services.create!(name: 'Fiscal')
    other_parent = account.ticket_services.create!(name: 'Financeiro')
    account.ticket_services.create!(name: 'NF-e', parent: parent)

    expect(account.ticket_services.new(name: 'nf-e', parent: other_parent)).to be_valid
    expect(account.ticket_services.new(name: 'nf-e', parent: parent)).not_to be_valid
  end
end
