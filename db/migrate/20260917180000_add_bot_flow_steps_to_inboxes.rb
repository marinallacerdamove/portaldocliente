class AddBotFlowStepsToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :bot_flow_steps, :jsonb, null: false, default: []
  end
end
