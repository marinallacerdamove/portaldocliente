# PATCH LOCAL (fork) - macro compartilhada com equipes específicas
# (visibility "team" + team_ids) e grupo pra organizar a lista (Comercial,
# Fiscal, Suprimentos...), no lugar do prefixo no nome.
class AddTeamAndGroupToMacros < ActiveRecord::Migration[7.1]
  def change
    add_column :macros, :team_ids, :bigint, array: true, default: [], null: false
    add_column :macros, :group_name, :string
  end
end
