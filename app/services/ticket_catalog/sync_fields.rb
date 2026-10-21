# PATCH LOCAL (fork) - contrato do cadastro de atendimento com o Portal do
# Cliente (dono do cadastro): por tipo de cadastro, a chave do contrato, a
# listagem do fork e os campos sincronizados. Único lugar que conhece essas
# listas; o endpoint de escrita, o evento de saída e o model leem daqui.
module TicketCatalog::SyncFields
  CATALOGS = {
    'servico' => { model: 'TicketService', association: :ticket_services },
    'tipo' => { model: 'TicketCategory', association: :ticket_categories },
    'status' => { model: 'TicketStatus', association: :ticket_statuses },
    'justificativa' => { model: 'TicketJustification', association: :ticket_justifications },
    'motivo' => { model: 'TicketCloseReason', association: :ticket_close_reasons },
    'campo' => { model: 'TicketCustomField', association: :ticket_custom_fields },
    'regra' => { model: 'TicketFieldRule', association: :ticket_field_rules }
  }.freeze

  # Colunas que vão como estão (mesmo nome no contrato).
  COLUMNS = {
    'servico' => %w[name description active position ticket_scope visible_to_clients allow_finish all_categories default_priority],
    'tipo' => %w[name active position ticket_scope allowed_priorities],
    'status' => %w[name base ticket_scope requires_justification active position],
    'justificativa' => %w[name ticket_scope active position],
    'motivo' => %w[name active position],
    'campo' => %w[name field_type hint options active position],
    'regra' => %w[name active position]
  }.freeze

  # Referências a outros itens, trocadas por código (o id do fork não vale fora dele).
  REFERENCES = {
    'servico' => %w[parent_code category_codes default_category_code],
    'justificativa' => %w[status_codes],
    # Campos adicionais citados pela regra, pela chave (field_key) no lugar do id.
    'regra' => %w[conditions fields]
  }.freeze

  # Coluna que, ao mudar, muda o campo de código do contrato.
  COLUMN_REFERENCES = { 'parent_id' => 'parent_code', 'default_category_id' => 'default_category_code' }.freeze

  KEY_BY_MODEL = CATALOGS.to_h { |key, config| [config[:model], key] }.freeze

  def self.key_for(model_name)
    KEY_BY_MODEL.fetch(model_name)
  end

  def self.fields(key)
    COLUMNS.fetch(key) + REFERENCES.fetch(key, [])
  end

  # Condições e campos da regra com a chave do campo no lugar do id desta conta.
  def self.rule_wire(rule)
    keys = rule.account.ticket_custom_fields.pluck(:id, :key).to_h
    {
      conditions: rule.conditions.map do |condition|
        next condition.except('field_id') unless condition['attribute'] == 'campo'

        condition.except('field_id').merge('field_key' => keys[condition['field_id']])
      end,
      fields: rule.fields.map { |field| field.except('field_id').merge('field_key' => keys[field['field_id']]) }
    }
  end

  # Volta da chave para o id do campo na conta; devolve [entradas, chaves desconhecidas].
  def self.rule_from_wire(entries, account)
    ids = account.ticket_custom_fields.pluck(:key, :id).to_h
    missing = []
    converted = Array(entries).map do |entry|
      entry = entry.to_h.stringify_keys
      next entry unless entry.key?('field_key')

      missing << entry['field_key'] unless ids.key?(entry['field_key'])
      entry.except('field_key').merge('field_id' => ids[entry['field_key']])
    end
    [converted, missing]
  end
end
