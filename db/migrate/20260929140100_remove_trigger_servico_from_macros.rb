# PATCH LOCAL (fork) - a macro do serviço agora fica no cadastro do serviço
# (ticket_services.macro_id), como no Movidesk.
class RemoveTriggerServicoFromMacros < ActiveRecord::Migration[7.1]
  def change
    remove_index :macros, [:account_id, :trigger_servico], unique: true, where: 'trigger_servico IS NOT NULL'
    remove_column :macros, :trigger_servico, :string
  end
end
