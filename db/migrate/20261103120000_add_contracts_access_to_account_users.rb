# PATCH LOCAL (fork) - "Acesso a contratos" por agente (Configurações >
# Agentes > editar). Dá a permissão financeiro_manage sem perfil
# personalizado, que trocaria todas as permissões do agente.
class AddContractsAccessToAccountUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :account_users, :contracts_access, :boolean, default: false, null: false
  end
end
