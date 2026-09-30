# PATCH LOCAL (fork) - macro compartilhada com agentes específicos, além de
# (ou em vez de) equipes: visibility "team" + user_ids (Movidesk "com os
# seguintes agentes").
class AddUserIdsToMacros < ActiveRecord::Migration[7.1]
  def change
    add_column :macros, :user_ids, :bigint, array: true, default: [], null: false
  end
end
