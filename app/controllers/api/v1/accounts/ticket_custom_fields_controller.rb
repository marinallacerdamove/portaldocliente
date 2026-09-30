class Api::V1::Accounts::TicketCustomFieldsController < Api::V1::Accounts::BaseController
  include TicketCatalogActions

  CATALOG_MODEL = TicketCustomField

  private

  # A chave não entra: é gerada do nome na criação e fica fixa.
  def record_params
    params.require(:ticket_custom_field).permit(:name, :field_type, :hint, :active, :position, options: [])
  end
end
