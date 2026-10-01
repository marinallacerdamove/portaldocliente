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
end
