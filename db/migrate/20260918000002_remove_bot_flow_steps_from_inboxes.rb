class RemoveBotFlowStepsFromInboxes < ActiveRecord::Migration[7.1]
  def change
    remove_column :inboxes, :bot_flow_steps, :jsonb, default: [], null: false
  end
end
