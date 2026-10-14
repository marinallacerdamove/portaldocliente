# PATCH LOCAL (fork) - código de negócio dos cadastros de atendimento (serviço,
# categoria, status, justificativa, motivo de encerramento). O Portal do Cliente
# é o dono do código (SRV-0042, TIP-0007...); aqui a coluna nasce nula e só a
# sincronização do Portal a preenche, então nada muda até lá. Único por conta
# (homologação e produção usam contas diferentes do mesmo Chatwoot); item sem
# código fica fora do índice. Tabelas pequenas: índice normal, sem CONCURRENTLY.
class AddCodeToTicketCatalogs < ActiveRecord::Migration[7.1]
  TABLES = %i[ticket_services ticket_categories ticket_statuses ticket_justifications ticket_close_reasons].freeze

  def change
    TABLES.each do |table|
      add_column table, :code, :string
      add_index table, [:account_id, :code], unique: true, where: 'code IS NOT NULL', name: "index_#{table}_on_account_id_and_code"
    end
  end
end
