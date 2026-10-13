require 'rails_helper'

# PATCH LOCAL (fork) - Enterprise::Concerns::Contact#fill_empresa_on_open_conversations
RSpec.describe Contact, type: :model do
  describe 'filling "empresa" on open conversations when the contact company changes' do
    let(:account) { create(:account) }
    let(:contact) { create(:contact, account: account) }
    let(:acme) { create(:company, account: account, name: 'ACME') }
    let(:beta) { create(:company, account: account, name: 'Beta') }

    def conversation_for(contact, status: :open, custom_attributes: {})
      create(:conversation, account: account, contact: contact, status: status, custom_attributes: custom_attributes)
    end

    it 'fills the empty field of open conversations with the new company name' do
      open_conversation = conversation_for(contact)
      pending_conversation = conversation_for(contact, status: :pending)

      contact.update!(company: acme)

      expect(open_conversation.reload.custom_attributes['empresa']).to eq('ACME')
      expect(pending_conversation.reload.custom_attributes['empresa']).to eq('ACME')
    end

    it 'leaves resolved conversations alone' do
      resolved = conversation_for(contact, status: :resolved)

      contact.update!(company: acme)

      expect(resolved.reload.custom_attributes).not_to have_key('empresa')
    end

    it 'replaces the previous company name that was filled in automatically' do
      contact.update!(company: acme)
      conversation = conversation_for(contact)
      expect(conversation.reload.custom_attributes['empresa']).to eq('ACME')

      contact.update!(company: beta)

      expect(conversation.reload.custom_attributes['empresa']).to eq('Beta')
    end

    it 'keeps a value an agent chose by hand' do
      contact.update!(company: acme)
      conversation = conversation_for(contact, custom_attributes: { 'empresa' => 'Escolhida por agente' })

      contact.update!(company: beta)

      expect(conversation.reload.custom_attributes['empresa']).to eq('Escolhida por agente')
    end

    it 'does nothing when the company is removed' do
      contact.update!(company: acme)
      conversation = conversation_for(contact)

      contact.update!(company: nil)

      expect(conversation.reload.custom_attributes['empresa']).to eq('ACME')
    end

    it 'does not run when other contact fields change' do
      conversation = conversation_for(contact)

      contact.update!(name: 'Novo nome')

      expect(conversation.reload.custom_attributes).not_to have_key('empresa')
    end
  end
end
