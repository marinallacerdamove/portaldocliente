json.id resource.id
json.name resource.name
json.contacts_count resource.contacts_count
json.domain resource.domain
json.description resource.description
# PATCH LOCAL (fork) - campos de Contrato/Financeiro somem da resposta pra
# quem não tem CompanyPolicy#financeiro_manage? (ver companies_controller.rb)
# - sem isso, esconder a aba Financeiro no frontend não impede ler o dado
# direto da API.
json.custom_attributes(
  @can_view_financeiro ? resource.custom_attributes : resource.custom_attributes.excluding(*Api::V1::Accounts::CompaniesController::FINANCEIRO_KEYS)
)
json.avatar_url resource.avatar_url
json.last_activity_at resource.last_activity_at.to_i if resource[:last_activity_at].present?
json.created_at resource.created_at.to_i if resource[:created_at].present?
json.updated_at resource.updated_at.to_i if resource[:updated_at].present?
