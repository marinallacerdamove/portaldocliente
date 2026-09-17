class CreateBotFlows < ActiveRecord::Migration[7.1]
  def change
    create_table :bot_flows do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :trigger_type, null: false, default: 0
      t.jsonb :trigger_config, null: false, default: {}
      t.bigint :inbox_ids, array: true, null: false, default: []
      t.integer :priority, null: false, default: 0
      t.jsonb :nodes, null: false, default: []
      t.jsonb :edges, null: false, default: []

      t.timestamps
    end

    add_index :bot_flows, :account_id
    add_index :bot_flows, :inbox_ids, using: :gin
  end
end
