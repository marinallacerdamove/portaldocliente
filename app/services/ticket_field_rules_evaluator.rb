# PATCH LOCAL (fork) - regras de exibição dos campos adicionais avaliadas no
# servidor, pra cobrar os obrigatórios "na conclusão" ao resolver também fora
# da tela (ver Conversations::ResolveRequirementsService). Mesma lógica de
# app/javascript/dashboard/helper/ticketFieldRules.js e da cópia do Portal
# (backend/app/services/ticket_field_rules.rb) - mudou um, muda todos.
#
# rules: TicketFieldRule (ou hashes com active/conditions/fields), fields:
# TicketCustomField; context: { servico:, tipo_de_solicitacao:, status:,
# concluded:, origem:, empresa:, equipe:, responsavel:, values: }.
class TicketFieldRulesEvaluator
  def self.empty_value?(value)
    value.nil? || (value.is_a?(Array) ? value.empty? : value.to_s.strip.empty?)
  end

  def self.missing_required(items, values, moments)
    items.select { |item| moments.include?(item['required_on']) && empty_value?((values || {})[item['field'].key]) }
  end

  def initialize(rules:, fields:)
    @fields_by_id = fields.select(&:active).index_by(&:id)
    @rules = rules.map { |rule| rule.as_json.stringify_keys }.select { |rule| rule['active'] }
  end

  # [{ 'field' => TicketCustomField, 'required_on' =>, ... }] na ordem das
  # regras; campo em mais de uma regra fica com a configuração da primeira.
  # Repete até estabilizar (mostrar um campo pode abrir outra regra).
  def visible_items(context)
    visible_ids = Set.new
    items, ids = items_for(context, visible_ids)
    @rules.size.times do
      break if ids == visible_ids

      visible_ids = ids
      items, ids = items_for(context, visible_ids)
    end
    items
  end

  private

  def items_for(context, visible_ids)
    ids = Set.new
    items = @rules.select { |rule| rule_matches?(rule, context, visible_ids) }.flat_map do |rule|
      Array(rule['fields']).filter_map do |rule_field|
        field = @fields_by_id[rule_field['field_id']]
        next if field.nil? || ids.include?(field.id)

        ids << field.id
        rule_field.stringify_keys.merge('field' => field)
      end
    end
    [items, ids]
  end

  def rule_matches?(rule, context, visible_ids)
    matches = ->(condition) { condition_matches?(condition, context, visible_ids) }
    all, any = condition_groups(rule)
    all.all?(&matches) && (any.empty? || any.any?(&matches))
  end

  def condition_groups(rule)
    conditions = Array(rule['conditions']).map(&:stringify_keys)
    [conditions.select { |c| c['group'] == 'all' }, conditions.select { |c| c['group'] == 'any' }]
  end

  def condition_matches?(condition, context, visible_ids)
    attribute, operator, value = condition.values_at('attribute', 'operator', 'value')
    return status_not_concluded_matches?(operator, context) if attribute == 'status' && value == TicketFieldRule::STATUS_NOT_CONCLUDED
    # Campo escondido não conta na cascata (valor antigo não reabre regra).
    return false if attribute == 'campo' && visible_ids.exclude?(condition['field_id'])

    current = condition_value(condition, context)
    return !self.class.empty_value?(current) if operator == 'is_present'

    value_matches?(current, value) == (operator == 'equal_to')
  end

  def condition_value(condition, context)
    return context[condition['attribute'].to_s.to_sym] unless condition['attribute'] == 'campo'

    (context[:values] || {})[@fields_by_id[condition['field_id']].key]
  end

  # Seleção múltipla: "igual a" = a opção está marcada.
  def value_matches?(current, value)
    (current.is_a?(Array) ? current : [current]).any? { |item| item.to_s.strip == value }
  end

  def status_not_concluded_matches?(operator, context)
    return true if operator == 'is_present'

    operator == 'equal_to' ? !context[:concluded] : !!context[:concluded]
  end
end
