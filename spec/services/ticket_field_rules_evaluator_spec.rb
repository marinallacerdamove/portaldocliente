require 'rails_helper'

# Mesmos casos de app/javascript/dashboard/helper/specs/ticketFieldRules.spec.js: o
# servidor tem que avaliar as regras igual à tela.
RSpec.describe TicketFieldRulesEvaluator do
  let(:field_stub) { Struct.new(:id, :key, :name, :active) }
  let(:fields) { [field(1, 'classificacao_com'), field(2, 'checklist_tintometrico'), field(3, 'inativo', active: false)] }
  let(:rules) do
    [
      { 'active' => true,
        'conditions' => [cond('all', 'servico', 'equal_to', 'ALBATROSS › 04. Comercial'),
                         cond('any', 'tipo_de_solicitacao', 'equal_to', 'Dúvida'),
                         cond('any', 'tipo_de_solicitacao', 'equal_to', 'Configuração')],
        'fields' => [rule_field(1, required_on: 'conclusao'), rule_field(3)] },
      { 'active' => true,
        'conditions' => [cond('all', 'campo', 'equal_to', 'Tintométrico', field_id: 1)],
        'fields' => [rule_field(2, required_on: 'conclusao')] }
    ]
  end
  let(:base) { { servico: 'ALBATROSS › 04. Comercial', tipo_de_solicitacao: 'Dúvida', values: {} } }

  def field(id, key, active: true) = field_stub.new(id, key, key, active)

  def rule_field(field_id, **extra)
    { 'field_id' => field_id, 'columns' => 12, 'visible_to_clients' => true, 'editable_by_clients' => false,
      'editable_by_agents' => true, 'required_on' => 'nao_exigir' }.merge(extra.stringify_keys)
  end

  def cond(group, attribute, operator, value = nil, field_id: nil)
    { 'group' => group, 'attribute' => attribute, 'operator' => operator, 'value' => value, 'field_id' => field_id }.compact
  end

  def keys_for(context, rule_list = rules, field_list = fields)
    described_class.new(rules: rule_list, fields: field_list).visible_items(context).map { |item| item['field'].key }
  end

  it 'mostra a classificação quando serviço (all) e um tipo (any) batem' do
    expect(keys_for(base)).to eq(['classificacao_com'])
  end

  it 'não mostra quando nenhuma condição "any" bate' do
    expect(keys_for(base.merge(tipo_de_solicitacao: 'Bug'))).to eq([])
  end

  it 'abre o checklist pelo valor da classificação (cascata)' do
    expect(keys_for(base.merge(values: { 'classificacao_com' => 'Tintométrico' }))).to eq(%w[classificacao_com checklist_tintometrico])
  end

  it 'valor de campo escondido não mantém a cascata aberta' do
    expect(keys_for(base.merge(servico: 'Outro', values: { 'classificacao_com' => 'Tintométrico' }))).to eq([])
  end

  it 'ignora regra inativa' do
    expect(keys_for(base, rules.map { |rule| rule.merge('active' => false) })).to eq([])
  end

  it '"diferente de", "informada" e seleção múltipla' do
    extra_rules = [
      { 'active' => true,
        'conditions' => [cond('all', 'servico', 'not_equal_to', 'Z. DynamicRD'), cond('all', 'campo', 'equal_to', 'Opção B', field_id: 2)],
        'fields' => [rule_field(4)] },
      { 'active' => true, 'conditions' => [cond('all', 'campo', 'is_present', field_id: 4)], 'fields' => [rule_field(5)] }
    ]
    context = base.merge(values: { 'classificacao_com' => 'Tintométrico', 'checklist_tintometrico' => ['Opção A', 'Opção B'], 'extra' => 'x' })
    expect(keys_for(context, rules + extra_rules, fields + [field(4, 'extra'), field(5, 'final')]))
      .to eq(%w[classificacao_com checklist_tintometrico extra final])
  end

  it 'status "não concluído"' do
    status_rules = [{ 'active' => true, 'conditions' => [cond('all', 'status', 'equal_to', TicketFieldRule::STATUS_NOT_CONCLUDED)],
                      'fields' => [rule_field(1)] }]
    expect(keys_for({ concluded: false }, status_rules)).to eq(['classificacao_com'])
    expect(keys_for({ concluded: true }, status_rules)).to eq([])
  end

  it 'lista só os obrigatórios do momento que estão vazios' do
    items = described_class.new(rules: rules, fields: fields).visible_items(base.merge(values: { 'classificacao_com' => 'Tintométrico' }))
    values = { 'classificacao_com' => 'Tintométrico', 'checklist_tintometrico' => [] }
    expect(described_class.missing_required(items, values, ['conclusao']).map { |item| item['field'].key }).to eq(['checklist_tintometrico'])
    expect(described_class.missing_required(items, values, ['abertura'])).to eq([])
  end
end
