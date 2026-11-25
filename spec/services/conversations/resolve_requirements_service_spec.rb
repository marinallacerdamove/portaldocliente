require 'rails_helper'

RSpec.describe Conversations::ResolveRequirementsService do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) do
    create(:conversation, account: account, assignee: agent, priority: :medium,
                          custom_attributes: { 'servico' => 'ALBATROSS', 'empresa' => 'ACME' })
  end

  def missing = described_class.new(conversation.reload).missing

  it 'nada falta quando a conta não cobra atributo e a conversa tem prioridade e agente' do
    expect(missing).to eq([])
  end

  it 'cobra Ações da conversa: atributo cadastrado vazio, prioridade, agente e time (se a conta tem time)' do
    create(:custom_attribute_definition, account: account, attribute_model: :conversation_attribute,
                                         attribute_key: 'tipo_de_solicitao', attribute_display_name: 'Tipo de solicitação')
    create(:team, account: account)
    conversation.update!(assignee: nil, priority: nil)

    expect(missing).to eq(['Tipo de solicitação', 'Prioridade', 'Agente', 'Time'])
  end

  it 'cobra o motivo de encerramento quando o atributo existe' do
    create(:custom_attribute_definition, account: account, attribute_model: :conversation_attribute,
                                         attribute_key: 'motivo_encerramento', attribute_display_name: 'Motivo de encerramento')
    expect(missing).to eq(['Motivo de encerramento'])

    conversation.update!(custom_attributes: conversation.custom_attributes.merge('motivo_encerramento' => 'Resolvido'))
    expect(missing).to eq([])
  end

  it 'cobra campo adicional obrigatório na conclusão que a regra mostra' do
    field = TicketCustomField.create!(account: account, name: 'Causa', field_type: 'text')
    TicketFieldRule.create!(account: account, name: 'Causa',
                            conditions: [{ group: 'all', attribute: 'servico', operator: 'equal_to', value: 'ALBATROSS' }],
                            fields: [{ field_id: field.id, required_on: 'conclusao' }])
    expect(missing).to eq(['Causa'])

    conversation.update!(custom_attributes: conversation.custom_attributes.merge('campos_adicionais' => { field.key => 'x' }))
    expect(missing).to eq([])
  end

  describe 'origem usada nas regras de exibição' do
    let(:field) { TicketCustomField.create!(account: account, name: 'Causa', field_type: 'text') }

    before do
      TicketFieldRule.create!(account: account, name: 'Só agente',
                              conditions: [{ group: 'all', attribute: 'origem', operator: 'equal_to', value: 'agente' }],
                              fields: [{ field_id: field.id, required_on: 'conclusao' }])
    end

    it 'não é agente numa conversa de caixa comum sem visivel_parceiro' do
      expect(missing).to eq([])
    end

    it 'é agente quando o Portal marca visivel_parceiro como false (booleano ou texto)' do
      [false, 'false'].each do |value|
        conversation.update!(custom_attributes: conversation.custom_attributes.merge('visivel_parceiro' => value))
        expect(missing).to eq(['Causa'])
      end
    end

    it 'continua pela caixa quando visivel_parceiro é true ou ausente' do
      conversation.update!(custom_attributes: conversation.custom_attributes.merge('visivel_parceiro' => true))
      expect(missing).to eq([])
    end

    it 'é agente na caixa Tickets Internos' do
      conversation.update!(inbox: create(:inbox, account: account, name: TicketContract::INTERNAL_TICKETS_INBOX_NAME))
      expect(missing).to eq(['Causa'])
    end
  end

  it 'gives the same answer with the account data computed once by the caller' do
    create(:custom_attribute_definition, account: account, attribute_model: :conversation_attribute,
                                         attribute_key: 'tipo_de_solicitao', attribute_display_name: 'Tipo de solicitação')
    create(:team, account: account)
    conversation.update!(assignee: nil)
    account_data = described_class.account_data(account)

    expect(described_class.new(conversation.reload, account_data: account_data).missing).to eq(missing)
  end

  # Movidesk: "somente as equipes". Campo da regra restrito a uma equipe só é cobrado (e editado) por quem é
  # dela ou administrador; sem usuário (integração, automação) continua como antes.
  describe 'campo restrito a equipes' do
    let(:field) { TicketCustomField.create!(account: account, name: 'Criticidade do cliente', field_type: 'text') }
    let(:team) { create(:team, account: account, name: 'tecnologia e infraestrutura') }
    let(:admin) { create(:user, account: account, role: :administrator) }

    before do
      # Sem callback: trocar o time pela atribuição tiraria o agente que não é dele.
      conversation.update_columns(team_id: team.id) # rubocop:disable Rails/SkipsModelValidations
      TicketFieldRule.create!(account: account, name: 'Interno', fields: [
                                { field_id: field.id, required_on: 'conclusao', team_names: ['Tecnologia e Infraestrutura'] }
                              ])
    end

    def service_for(user) = described_class.new(conversation.reload, user: user)

    it 'não cobra nem libera para o agente de fora da equipe' do
      expect(service_for(agent).missing).to eq([])
      expect(service_for(agent).team_locked_field_keys).to eq([field.key])
    end

    it 'cobra e libera para o agente da equipe (nome sem diferenciar maiúsculas) e para o administrador' do
      create(:team_member, team: team, user: agent)

      [agent, admin].each do |user|
        expect(service_for(user).missing).to eq(['Criticidade do cliente'])
        expect(service_for(user).team_locked_field_keys).to eq([])
      end
    end

    it 'sem usuário continua cobrando como antes' do
      expect(described_class.new(conversation.reload).missing).to eq(['Criticidade do cliente'])
    end
  end
end
