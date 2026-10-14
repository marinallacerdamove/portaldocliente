# PATCH LOCAL (fork) - troca exata do valor antigo pelo novo do atributo de
# conversa de um cadastro (servico, tipo_de_solicitao, status_atendimento...)
# nas regras de exibição, macros e automações. Tabelas pequenas, por isso em
# Ruby; update_columns pra não rodar callback nem mexer em updated_at. Uma
# passada só pelo mapa: um valor novo nunca é trocado de novo.
#
# mapping: { valor antigo => valor novo }. Chamar dentro da transação do rename.
class TicketCatalog::DependentsRename
  # Chave do atributo de conversa -> nome do atributo nas condições da regra de exibição.
  RULE_ATTRIBUTES = {
    TicketContract::SERVICE_KEY => 'servico',
    TicketContract::CATEGORY_KEY => 'tipo_de_solicitacao',
    TicketContract::STATUS_KEY => 'status'
  }.freeze
  SET_ATTRIBUTE_ACTION = 'set_custom_attribute'.freeze

  def initialize(account_id, key, mapping)
    @account_id = account_id
    @key = key
    @mapping = mapping
  end

  def call
    swap_field_rules
    swap_macros
    swap_automation_rules
  end

  private

  def swap_field_rules
    rule_attribute = RULE_ATTRIBUTES[@key]
    return unless rule_attribute

    TicketFieldRule.where(account_id: @account_id).find_each do |rule|
      conditions = Array(rule.conditions).map do |condition|
        condition['attribute'] == rule_attribute ? condition.merge('value' => swapped(condition['value'])) : condition
      end
      rule.update_columns(conditions: conditions) if conditions != rule.conditions # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def swap_macros
    Macro.where(account_id: @account_id).find_each do |macro|
      actions = swap_actions(macro.actions)
      macro.update_columns(actions: actions) if actions != macro.actions # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def swap_automation_rules
    AutomationRule.where(account_id: @account_id).find_each do |rule|
      changes = { conditions: swap_automation_conditions(rule.conditions), actions: swap_actions(rule.actions) }
      changes = changes.reject { |column, value| value == rule[column] }
      rule.update_columns(changes) if changes.any? # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def swap_actions(actions)
    Array(actions).map do |action|
      params = action['action_params']
      next action unless action['action_name'] == SET_ATTRIBUTE_ACTION && params.is_a?(Array) && params.first == @key

      action.merge('action_params' => [params.first, swapped(params.second), *params.drop(2)])
    end
  end

  def swap_automation_conditions(conditions)
    Array(conditions).map do |condition|
      next condition unless condition['attribute_key'] == @key

      condition.merge('values' => Array(condition['values']).map { |value| swapped(value) })
    end
  end

  def swapped(value)
    @mapping.fetch(value, value)
  end
end
