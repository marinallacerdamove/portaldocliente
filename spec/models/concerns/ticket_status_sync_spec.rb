require 'rails_helper'

RSpec.describe TicketStatusSync do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  def ticket_status(conversation) = conversation.reload.custom_attributes['status_atendimento']

  context 'when the account has no registered statuses' do
    it 'leaves custom attributes and native status alone' do
      conversation.update!(status: :resolved)

      expect(conversation.reload).to be_resolved
      expect(conversation.custom_attributes).not_to have_key('status_atendimento')
    end
  end

  context 'when the account has registered statuses' do
    before do
      account.ticket_statuses.create!(name: 'Novo', base: 'novo', position: 0)
      account.ticket_statuses.create!(name: 'Em atendimento', base: 'em_atendimento', position: 1)
      account.ticket_statuses.create!(name: 'Parado', base: 'parado', position: 2)
      account.ticket_statuses.create!(name: 'Resolvido', base: 'resolvido', position: 3)
      account.ticket_statuses.create!(name: 'Fechado', base: 'fechado', position: 4)
    end

    it 'gives a new open conversation the "novo" status' do
      expect(ticket_status(create(:conversation, account: account))).to eq('Novo')
    end

    it 'keeps the status the creator picked when it matches the native status' do
      created = create(:conversation, account: account, custom_attributes: { 'status_atendimento' => 'Em atendimento' })

      expect(created.reload).to be_open
      expect(ticket_status(created)).to eq('Em atendimento')
    end

    describe 'picking a registered status' do
      it 'sets the native status by the status type' do
        conversation.update!(custom_attributes: { 'status_atendimento' => 'Parado' })
        expect(conversation.reload).to be_pending

        conversation.update!(custom_attributes: { 'status_atendimento' => 'Fechado' })
        expect(conversation.reload).to be_resolved
      end

      it 'ignores a name that is not registered' do
        conversation.update!(custom_attributes: { 'status_atendimento' => 'Inventado' })

        expect(conversation.reload).to be_open
      end

      it 'is a resolving pick only for statuses that resolve and while not resolved yet' do
        conversation.custom_attributes = { 'status_atendimento' => 'Fechado' }
        expect(conversation).to be_resolving_by_ticket_status

        conversation.custom_attributes = { 'status_atendimento' => 'Parado' }
        expect(conversation).not_to be_resolving_by_ticket_status
      end
    end

    describe 'following the native status' do
      it 'picks the first status of the new native status when the current one does not match' do
        conversation.update!(status: :resolved)
        expect(ticket_status(conversation)).to eq('Resolvido')

        conversation.update!(status: :pending)
        expect(ticket_status(conversation)).to eq('Parado')

        conversation.update!(status: :open)
        expect(ticket_status(conversation)).to eq('Em atendimento')
      end

      it 'keeps the current status when it is already compatible with the new native status' do
        conversation.update!(custom_attributes: { 'status_atendimento' => 'Fechado' })
        conversation.update!(status: :resolved)

        expect(ticket_status(conversation)).to eq('Fechado')
      end

      it 'skips inactive statuses' do
        account.ticket_statuses.find_by(name: 'Resolvido').update!(active: false)
        conversation.update!(status: :resolved)

        expect(ticket_status(conversation)).to eq('Fechado')
      end

      it 'never leaves the conversation without a status when a stale save blanks it' do
        conversation.update!(status: :pending)
        conversation.update!(custom_attributes: conversation.custom_attributes.merge('status_atendimento' => ''))

        expect(ticket_status(conversation)).to eq('Parado')
      end
    end

    describe 'justification' do
      let(:justification) { account.ticket_justifications.create!(name: 'Aguardando cliente') }

      before do
        account.ticket_statuses.find_by(name: 'Parado').justifications << justification
        conversation.update!(custom_attributes: { 'status_atendimento' => 'Parado', 'justificativa' => 'Aguardando cliente' })
      end

      it 'is kept while the status accepts it' do
        expect(conversation.reload.custom_attributes['justificativa']).to eq('Aguardando cliente')
      end

      it 'is dropped when the status changes to one that does not accept it' do
        conversation.update!(custom_attributes: conversation.custom_attributes.merge('status_atendimento' => 'Em atendimento'))

        expect(conversation.reload.custom_attributes).not_to have_key('justificativa')
      end
    end

    describe 'reopening' do
      it 'clears the close reason, which only holds for the current resolution' do
        conversation.update!(status: :resolved, custom_attributes: conversation.custom_attributes.merge('motivo_encerramento' => 'Resolvido'))
        expect(conversation.reload.custom_attributes['motivo_encerramento']).to eq('Resolvido')

        conversation.update!(status: :open)

        expect(conversation.reload.custom_attributes).not_to have_key('motivo_encerramento')
      end
    end
  end

  it 'clears the close reason on reopen even when the account has no registered statuses' do
    conversation.update!(status: :resolved, custom_attributes: { 'motivo_encerramento' => 'Resolvido' })
    conversation.update!(status: :open)

    expect(conversation.reload.custom_attributes).not_to have_key('motivo_encerramento')
  end
end
