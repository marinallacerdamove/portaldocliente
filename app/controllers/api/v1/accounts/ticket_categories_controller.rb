class Api::V1::Accounts::TicketCategoriesController < Api::V1::Accounts::BaseController
  include TicketCatalogActions

  CATALOG_MODEL = TicketCategory

  private

  def record_params
    params.require(:ticket_category).permit(:name, :active, :ticket_scope, :position, allowed_priorities: [])
  end
end
