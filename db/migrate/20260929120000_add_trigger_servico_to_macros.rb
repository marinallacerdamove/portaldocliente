# PATCH LOCAL (fork) - macro aplicada sozinha quando o atendente escolhe esse
# serviço na conversa (paridade com o "serviço com macro" do Movidesk).
class AddTriggerServicoToMacros < ActiveRecord::Migration[7.1]
  def change
    add_column :macros, :trigger_servico, :string
    add_index :macros, [:account_id, :trigger_servico], unique: true, where: 'trigger_servico IS NOT NULL'
  end
end
