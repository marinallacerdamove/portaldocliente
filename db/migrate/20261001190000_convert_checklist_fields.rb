# PATCH LOCAL (fork) - checklists do Movidesk (seleção múltipla "Checklist: ...")
# viram o tipo checklist, igual no Portal. O de escolha única fica como está.
class ConvertChecklistFields < ActiveRecord::Migration[7.1]
  def up
    execute("UPDATE ticket_custom_fields SET field_type = 'checklist' WHERE field_type = 'multi_select' AND name ILIKE 'Checklist%'")
  end

  def down
    execute("UPDATE ticket_custom_fields SET field_type = 'multi_select' WHERE field_type = 'checklist'")
  end
end
