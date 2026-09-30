# PATCH LOCAL (fork) - regra de exibição de campos adicionais (Movidesk:
# Regras para exibição). Aparece quando TODAS as condições "all" batem e, se
# houver condição "any", pelo menos uma delas. Quem avalia é a tela (conversa
# e Portal), com os valores atuais do ticket; aqui só se valida o formato.
#
# conditions: [{ group: 'all'|'any', attribute:, operator:, value:, field_id: }]
#   attribute 'campo' compara o valor de outro campo adicional (field_id) -
#   é isso que monta a cascata Classificação do Serviço -> Tipo -> Checklist.
#   Valores por nome, igual a conversa guarda (serviço = caminho completo).
# fields: [{ field_id:, columns: 1..12, visible_to_clients:, editable_by_clients:,
#   editable_by_agents:, required_on: }] - na ordem de exibição.
class TicketFieldRule < ApplicationRecord
  GROUPS = %w[all any].freeze
  ATTRIBUTES = %w[servico tipo_de_solicitacao status campo origem empresa equipe responsavel].freeze
  OPERATORS = %w[equal_to not_equal_to is_present].freeze
  # Status especial do Movidesk: qualquer status que não encerra o ticket.
  STATUS_NOT_CONCLUDED = '__nao_concluido'.freeze
  ORIGINS = %w[cliente agente chat whatsapp email].freeze
  REQUIRED_ON = %w[nao_exigir abertura_agente abertura_cliente abertura conclusao].freeze
  FIELD_FLAGS = %w[visible_to_clients editable_by_clients editable_by_agents].freeze

  belongs_to :account

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  validates :name, presence: true
  validate :conditions_shape
  validate :fields_shape

  before_validation :normalize

  def as_json(*)
    slice(:id, :name, :active, :conditions, :fields, :position)
  end

  private

  def normalize
    self.name = name.to_s.squish
    self.conditions = Array(conditions).map { |condition| normalize_condition(condition.to_h.stringify_keys) }
    self.fields = Array(fields).map { |field| normalize_field(field.to_h.stringify_keys) }.uniq { |field| field['field_id'] }
  end

  def normalize_condition(condition)
    normalized = condition.slice('group', 'attribute', 'operator').transform_values(&:to_s)
    normalized['value'] = condition['value'].to_s.strip unless normalized['operator'] == 'is_present'
    normalized['field_id'] = condition['field_id'].to_i if normalized['attribute'] == 'campo'
    normalized
  end

  def normalize_field(field)
    normalized = { 'field_id' => field['field_id'].to_i, 'columns' => (field['columns'].presence || 12).to_i,
                   'required_on' => field['required_on'].presence || 'nao_exigir' }
    FIELD_FLAGS.each { |flag| normalized[flag] = ActiveModel::Type::Boolean.new.cast(field.fetch(flag, flag == 'editable_by_agents')) || false }
    normalized
  end

  def account_field_ids
    @account_field_ids ||= TicketCustomField.where(account_id: account_id).pluck(:id).to_set
  end

  def conditions_shape
    conditions.each do |condition|
      next if GROUPS.include?(condition['group']) && ATTRIBUTES.include?(condition['attribute']) &&
              OPERATORS.include?(condition['operator']) && condition_target_valid?(condition)

      errors.add(:conditions, :invalid)
      break
    end
  end

  def condition_target_valid?(condition)
    return false if condition['attribute'] == 'campo' && account_field_ids.exclude?(condition['field_id'])
    return false if condition['attribute'] == 'origem' && condition['operator'] != 'is_present' && ORIGINS.exclude?(condition['value'])

    condition['operator'] == 'is_present' || condition['value'].present?
  end

  def fields_shape
    errors.add(:fields, :blank) if fields.empty?
    return if fields.all? do |field|
      account_field_ids.include?(field['field_id']) && field['columns'].between?(1, 12) && REQUIRED_ON.include?(field['required_on'])
    end

    errors.add(:fields, :invalid)
  end
end
