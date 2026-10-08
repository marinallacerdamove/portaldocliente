require 'rails_helper'

RSpec.describe Conversations::TicketLinkService do
  let(:account) { create(:account) }
  let(:parent) { create(:conversation, account: account) }
  let(:child) { create(:conversation, account: account) }

  def link(parent_conversation, child_conversation)
    described_class.new(parent: parent_conversation, child: child_conversation).perform
  end

  it 'writes both sides of the link' do
    link(parent, child)

    expect(child.reload.custom_attributes['ticket_pai_id']).to eq(parent.display_id.to_s)
    expect(parent.reload.custom_attributes['ticket_filhos_ids']).to eq(child.display_id.to_s)
  end

  it 'keeps the other custom attributes of both conversations' do
    parent.update!(custom_attributes: { 'assunto' => 'Pai' })
    child.update!(custom_attributes: { 'assunto' => 'Filho' })

    link(parent, child)

    expect(parent.reload.custom_attributes['assunto']).to eq('Pai')
    expect(child.reload.custom_attributes['assunto']).to eq('Filho')
  end

  it 'does not repeat a child already listed' do
    link(parent, child)
    link(parent, child)

    expect(parent.reload.custom_attributes['ticket_filhos_ids']).to eq(child.display_id.to_s)
  end

  it 'moves the child out of the previous parent list' do
    other_child = create(:conversation, account: account)
    previous_parent = create(:conversation, account: account)
    link(previous_parent, other_child)
    link(previous_parent, child)
    new_parent = create(:conversation, account: account)

    changed = link(new_parent, child)

    expect(previous_parent.reload.custom_attributes['ticket_filhos_ids']).to eq(other_child.display_id.to_s)
    expect(child.reload.custom_attributes['ticket_pai_id']).to eq(new_parent.display_id.to_s)
    expect(changed).to contain_exactly(new_parent, child, previous_parent)
  end

  it 'drops the list key when the previous parent has no children left' do
    previous_parent = create(:conversation, account: account)
    link(previous_parent, child)

    link(parent, child)

    expect(previous_parent.reload.custom_attributes).not_to have_key('ticket_filhos_ids')
  end

  it 'refuses to link a conversation to itself' do
    expect { link(parent, parent) }.to raise_error(described_class::InvalidLink, 'self')
  end

  it 'refuses a link that makes a cycle' do
    grandchild = create(:conversation, account: account)
    link(parent, child)
    link(child, grandchild)

    expect { link(grandchild, parent) }.to raise_error(described_class::InvalidLink, 'cycle')
    expect(parent.reload.custom_attributes).not_to have_key('ticket_pai_id')
  end
end
