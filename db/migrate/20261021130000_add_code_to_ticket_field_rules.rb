# PATCH LOCAL (fork) - código de negócio da regra de exibição (REG-0001...), dono
# o Portal do Cliente, como nos outros cadastros (AddCodeToTicketCatalogs): nasce
# nulo e só a sincronização com o Portal preenche. O campo adicional não precisa:
# a chave já é fixa e igual nos dois sistemas.
class AddCodeToTicketFieldRules < ActiveRecord::Migration[7.1]
  def change
    add_column :ticket_field_rules, :code, :string
    add_index :ticket_field_rules, [:account_id, :code], unique: true, where: 'code IS NOT NULL',
                                                         name: 'index_ticket_field_rules_on_account_id_and_code'
  end
end
