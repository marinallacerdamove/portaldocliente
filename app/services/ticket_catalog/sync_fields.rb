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
    'motivo' => { model: 'TicketCloseReason', association: :ticket_close_reasons }
  }.freeze

  # Colunas que vão como estão (mesmo nome no contrato).
  COLUMNS = {
    'servico' => %w[name description active position ticket_scope visible_to_clients allow_finish all_categories default_priority],
    'tipo' => %w[name active position ticket_scope allowed_priorities],
    'status' => %w[name base ticket_scope requires_justification active position],
    'justificativa' => %w[name ticket_scope active position],
    'motivo' => %w[name active position]
  }.freeze

  # Referências a outros itens, trocadas por código (o id do fork não vale fora dele).
  REFERENCES = {
    'servico' => %w[parent_code category_codes default_category_code],
    'justificativa' => %w[status_codes]
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
end
