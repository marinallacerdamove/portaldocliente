require 'rails_helper'

RSpec.describe TicketCatalogCodes do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  def coded(item, code)
    item.assign_code(code)
    item.save!
    item
  end

  def attributes_of(conversation) = conversation.reload.custom_attributes

  context 'when no item of the catalog has a code' do
    before do
      account.ticket_services.create!(name: 'Fiscal')
      account.ticket_categories.create!(name: 'Dúvida')
    end

    it 'does not add code keys on create or on update' do
      created = create(:conversation, account: account, custom_attributes: { 'servico' => 'Fiscal', 'tipo_de_solicitao' => 'Dúvida' })
      created.update!(custom_attributes: created.custom_attributes.merge('servico' => 'Nome solto'))

      expect(attributes_of(created).keys).to contain_exactly('servico', 'tipo_de_solicitao')
      expect(attributes_of(created)['servico']).to eq('Nome solto')
    end

    it 'leaves the ticket status behavior untouched' do
      account.ticket_statuses.create!(name: 'Novo', base: 'novo')
      account.ticket_statuses.create!(name: 'Parado', base: 'parado')
      conversation.update!(custom_attributes: { 'status_atendimento' => 'Parado' })

      expect(conversation.reload).to be_pending
      expect(attributes_of(conversation).keys).to eq(['status_atendimento'])
    end

    it 'strips a stray code key whose name is not in the catalog (nothing to keep it consistent)' do
      conversation.update!(custom_attributes: { 'servico' => 'Nome solto', 'servico_codigo' => 'SRV-0001' })

      expect(attributes_of(conversation)).to eq('servico' => 'Nome solto')
    end

    it 'does not query the catalog when neither name nor code changed' do
      conversation.update!(custom_attributes: { 'servico' => 'Fiscal' })

      allow(account).to receive(:ticket_services)
      conversation.update!(additional_attributes: { 'x' => 1 })

      expect(account).not_to have_received(:ticket_services)
    end
  end

  context 'when the catalog has codes' do
    let!(:fiscal) { coded(account.ticket_services.create!(name: 'Fiscal'), 'SRV-0001') }
    let!(:financeiro) { coded(account.ticket_services.create!(name: 'Financeiro'), 'SRV-0003') }

    before do
      coded(account.ticket_services.create!(name: 'NF-e', parent: fiscal), 'SRV-0002')
      account.ticket_services.create!(name: 'Sem código')
    end

    describe 'name picked, code derived' do
      it 'fills the code from the name (full path for services)' do
        conversation.update!(custom_attributes: { 'servico' => 'Fiscal › NF-e' })

        expect(attributes_of(conversation)).to eq('servico' => 'Fiscal › NF-e', 'servico_codigo' => 'SRV-0002')
      end

      it 'fills the code on create' do
        created = create(:conversation, account: account, custom_attributes: { 'servico' => 'Financeiro' })

        expect(attributes_of(created)['servico_codigo']).to eq('SRV-0003')
      end

      it 'swaps the code when the agent picks another item and the screen keeps the old code' do
        conversation.update!(custom_attributes: { 'servico' => 'Fiscal', 'servico_codigo' => 'SRV-0001' })
        conversation.update!(custom_attributes: { 'servico' => 'Financeiro', 'servico_codigo' => 'SRV-0001' })

        expect(attributes_of(conversation)).to eq('servico' => 'Financeiro', 'servico_codigo' => 'SRV-0003')
      end

      it 'drops the code when the picked item has no code yet' do
        conversation.update!(custom_attributes: { 'servico' => 'Fiscal' })
        conversation.update!(custom_attributes: { 'servico' => 'Sem código', 'servico_codigo' => 'SRV-0001' })

        expect(attributes_of(conversation)).to eq('servico' => 'Sem código')
      end

      it 'leaves an orphan name without code' do
        conversation.update!(custom_attributes: { 'servico' => 'Fiscal' })
        conversation.update!(custom_attributes: { 'servico' => 'Nome que sumiu', 'servico_codigo' => 'SRV-9999' })

        expect(attributes_of(conversation)).to eq('servico' => 'Nome que sumiu')
      end
    end

    describe 'empty name' do
      it 'removes the code' do
        conversation.update!(custom_attributes: { 'servico' => 'Fiscal' })
        conversation.update!(custom_attributes: { 'servico' => '', 'servico_codigo' => 'SRV-0001' })

        expect(attributes_of(conversation)).not_to have_key('servico_codigo')
      end

      it 'removes the code when the name key is dropped' do
        conversation.update!(custom_attributes: { 'servico' => 'Fiscal' })
        conversation.update!(custom_attributes: { 'servico_codigo' => 'SRV-0001' })

        expect(attributes_of(conversation)).to eq({})
      end
    end

    describe 'changed code that exists' do
      it 'sets the name from the code, which wins over the name sent along' do
        conversation.update!(custom_attributes: { 'servico' => 'Fiscal' })
        conversation.update!(custom_attributes: { 'servico' => 'Fiscal', 'servico_codigo' => 'SRV-0002' })

        expect(attributes_of(conversation)).to eq('servico' => 'Fiscal › NF-e', 'servico_codigo' => 'SRV-0002')
      end

      it 'accepts a code without any name (integration sending only the code)' do
        conversation.update!(custom_attributes: { 'servico_codigo' => 'SRV-0003' })

        expect(attributes_of(conversation)).to eq('servico' => 'Financeiro', 'servico_codigo' => 'SRV-0003')
      end
    end

    describe 'stale screen writing back an old name' do
      it 'restores the current name of the item that holds the code' do
        conversation.update!(custom_attributes: { 'servico' => 'Financeiro' })
        perform_enqueued_jobs { financeiro.update!(name: 'Financeiro e Cobrança') }
        conversation.update!(custom_attributes: { 'servico' => 'Financeiro', 'servico_codigo' => 'SRV-0003' })

        expect(attributes_of(conversation)).to eq('servico' => 'Financeiro e Cobrança', 'servico_codigo' => 'SRV-0003')
      end
    end

    describe 'other catalogs' do
      it 'handles request type, justification and close reason with their own keys' do
        category = coded(account.ticket_categories.create!(name: 'Dúvida'), 'TIP-0001')
        justification = coded(account.ticket_justifications.create!(name: 'Aguardando cliente'), 'JUS-0001')
        reason = coded(account.ticket_close_reasons.create!(name: 'Resolvido sem retorno'), 'MOT-0001')
        conversation.update!(custom_attributes: { 'tipo_de_solicitao' => category.name, 'justificativa' => justification.name,
                                                  'motivo_encerramento' => reason.name })

        expect(attributes_of(conversation)).to include('tipo_de_solicitao_codigo' => 'TIP-0001', 'justificativa_codigo' => 'JUS-0001',
                                                       'motivo_encerramento_codigo' => 'MOT-0001')
      end
    end
  end

  describe 'ordering with TicketStatusSync' do
    let!(:parado) { coded(account.ticket_statuses.create!(name: 'Parado', base: 'parado', position: 1), 'STS-0002') }

    before do
      coded(account.ticket_statuses.create!(name: 'Novo', base: 'novo', position: 0), 'STS-0001')
      coded(account.ticket_statuses.create!(name: 'Fechado', base: 'fechado', position: 2), 'STS-0003')
    end

    it 'resolves the name from the code before the status sync picks the native status' do
      conversation.update!(custom_attributes: { 'status_atendimento_codigo' => 'STS-0002' })

      expect(conversation.reload).to be_pending
      expect(attributes_of(conversation)).to eq('status_atendimento' => 'Parado', 'status_atendimento_codigo' => 'STS-0002')
    end

    it 'derives the code of the default status the sync chose' do
      created = create(:conversation, account: account)

      expect(attributes_of(created)).to eq('status_atendimento' => 'Novo', 'status_atendimento_codigo' => 'STS-0001')
    end

    it 'follows the native status change with the matching code' do
      conversation.update!(status: :resolved)

      expect(attributes_of(conversation)).to eq('status_atendimento' => 'Fechado', 'status_atendimento_codigo' => 'STS-0003')
    end

    it 'drops the justification code when the sync discards the justification' do
      allowed = coded(account.ticket_justifications.create!(name: 'Aguardando'), 'JUS-0001')
      parado.justifications << allowed
      coded(account.ticket_justifications.create!(name: 'Outra'), 'JUS-0002')
      conversation.update!(custom_attributes: { 'status_atendimento' => 'Parado', 'justificativa' => 'Aguardando' })
      expect(attributes_of(conversation)['justificativa_codigo']).to eq('JUS-0001')

      conversation.update!(custom_attributes: attributes_of(conversation).merge('status_atendimento' => 'Fechado'))

      expect(attributes_of(conversation)).not_to include('justificativa', 'justificativa_codigo')
    end
  end
end
