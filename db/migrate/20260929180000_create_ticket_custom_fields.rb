# PATCH LOCAL (fork) - campos adicionais e regras de exibição no estilo
# Movidesk. O campo é global da conta; a regra diz quando ele aparece
# (serviço, tipo de solicitação, valor de outro campo...) e como (colunas,
# quem vê/edita, quando é obrigatório). A conversa guarda os valores em
# custom_attributes.campos_adicionais, por chave do campo. Nunca excluídos,
# só inativados.
class CreateTicketCustomFields < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :ticket_custom_fields do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false
      t.string :key, null: false
      t.string :field_type, null: false, default: 'text'
      t.string :hint
      t.string :options, array: true, default: [], null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :ticket_custom_fields, [:account_id, :key], unique: true

    create_table :ticket_field_rules do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.jsonb :conditions, default: [], null: false
      t.jsonb :fields, default: [], null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
  end
end
