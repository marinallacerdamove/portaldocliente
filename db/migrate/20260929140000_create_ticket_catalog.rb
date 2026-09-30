# PATCH LOCAL (fork) - cadastros de atendimento no estilo Movidesk: serviços
# (árvore), categorias, status e justificativas. Nunca excluídos, só inativados.
class CreateTicketCatalog < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    create_table :ticket_categories do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.integer :ticket_scope, default: 2, null: false
      t.string :allowed_priorities, array: true, default: [], null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :ticket_categories, [:account_id, :name], unique: true

    create_table :ticket_services do |t|
      t.references :account, null: false, index: true
      t.references :parent, foreign_key: { to_table: :ticket_services }
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true, null: false
      t.integer :ticket_scope, default: 2, null: false
      t.boolean :visible_to_clients, default: true, null: false
      t.boolean :allow_finish, default: true, null: false
      t.boolean :all_categories, default: false, null: false
      t.references :default_category, foreign_key: { to_table: :ticket_categories }
      t.string :default_priority
      t.references :macro, foreign_key: { on_delete: :nullify }
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :ticket_services, [:account_id, :parent_id, :name], unique: true

    create_table :ticket_service_categories do |t| # rubocop:disable Rails/CreateTableWithTimestamps
      t.references :ticket_service, null: false, foreign_key: { on_delete: :cascade }
      t.references :ticket_category, null: false, foreign_key: { on_delete: :cascade }
    end
    add_index :ticket_service_categories, [:ticket_service_id, :ticket_category_id], unique: true, name: 'index_ticket_service_categories_unique'

    create_table :ticket_statuses do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false
      t.string :base, null: false
      t.integer :ticket_scope, default: 2, null: false
      t.boolean :requires_justification, default: false, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :ticket_statuses, [:account_id, :name], unique: true

    create_table :ticket_justifications do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false
      t.integer :ticket_scope, default: 2, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :ticket_justifications, [:account_id, :name], unique: true

    create_table :ticket_status_justifications do |t| # rubocop:disable Rails/CreateTableWithTimestamps
      t.references :ticket_status, null: false, foreign_key: { on_delete: :cascade }
      t.references :ticket_justification, null: false, foreign_key: { on_delete: :cascade }
    end
    add_index :ticket_status_justifications, [:ticket_status_id, :ticket_justification_id], unique: true,
                                                                                            name: 'index_ticket_status_justifications_unique'
  end
end
