require 'rails_helper'

RSpec.describe TicketFieldRule do
  let(:account) { create(:account) }
  let(:field) { TicketCustomField.create!(account: account, name: 'Criticidade do cliente', field_type: 'text') }

  # Movidesk: "somente as equipes" no campo da regra.
  describe 'team_names do campo da regra' do
    it 'limpa espaços, tira vazios e repetidos (sem diferenciar maiúsculas) e mantém a grafia recebida' do
      names = ['  Tecnologia   e Infraestrutura ', '', nil, 'tecnologia e infraestrutura', 'QA']
      rule = described_class.create!(account: account, name: 'Regra', fields: [{ field_id: field.id, team_names: names }])

      expect(rule.reload.fields.first['team_names']).to eq(['Tecnologia e Infraestrutura', 'QA'])
    end

    it 'sem equipe (ausente ou vazio) não grava a chave: todas as equipes editam, como antes' do
      rule = described_class.create!(account: account, name: 'Regra', fields: [{ field_id: field.id, team_names: [] }])

      expect(rule.reload.fields.first).not_to have_key('team_names')
    end
  end
end
