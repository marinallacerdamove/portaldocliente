# PATCH LOCAL (fork) - CPF/CNPJ único por conta no banco, não só na validação
# do model (Company#cnpj_unique_in_account): duas gravações ao mesmo tempo (ex.:
# sync do Portal e agente cadastrando) passavam as duas pela validação. Mesma
# normalização de Company::CNPJ_KEY_SQL; sem CPF/CNPJ não entra no índice.
# CONCURRENTLY: não trava escrita em companies com o sistema em uso.
class AddUniqueCnpjIndexToCompanies < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :companies,
              "account_id, upper(regexp_replace((custom_attributes ->> 'cnpj'::text), '[^0-9A-Za-z]'::text, ''::text, 'g'::text))",
              unique: true,
              algorithm: :concurrently,
              name: 'index_companies_on_account_id_and_cnpj_key',
              where: "(regexp_replace((custom_attributes ->> 'cnpj'::text), '[^0-9A-Za-z]'::text, ''::text, 'g'::text) <> ''::text)"
  end
end
