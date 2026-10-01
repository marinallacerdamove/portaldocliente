# PATCH LOCAL (fork) - cadastro de motivos de encerramento (o Resolver pede um
# deles). Antes a lista só existia no atributo de conversa motivo_encerramento,
# sem tela pra configurar; a tabela nasce com os valores que já estavam lá, na
# mesma ordem, pra não mudar nada nas conversas já resolvidas. Nunca excluído,
# só inativado.
class CreateTicketCloseReasons < ActiveRecord::Migration[7.1]
  def up
    create_table :ticket_close_reasons do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false
      t.integer :ticket_scope, default: 2, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :ticket_close_reasons, [:account_id, :name], unique: true

    seed_from_attribute_definitions
  end

  def down
    drop_table :ticket_close_reasons
  end

  private

  def seed_from_attribute_definitions
    now = Time.current
    rows = select_rows(<<~SQL.squish)
      SELECT account_id, attribute_values FROM custom_attribute_definitions
      WHERE attribute_key = 'motivo_encerramento' AND attribute_model = 0
    SQL
    rows.each do |account_id, values|
      names = (values.is_a?(String) ? JSON.parse(values) : values).map { |name| name.to_s.squish }.compact_blank.uniq
      names.each_with_index do |name, position|
        execute(sanitize_sql(['INSERT INTO ticket_close_reasons (account_id, name, position, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
                              account_id, name, position, now, now]))
      end
    end
  end

  def sanitize_sql(args)
    ActiveRecord::Base.sanitize_sql_array(args)
  end
end
