class Api::V1::Accounts::TicketStatusesController < Api::V1::Accounts::BaseController
  include TicketCatalogActions

  CATALOG_MODEL = TicketStatus

  private

  def record_params
    params.require(:ticket_status).permit(:name, :base, :active, :ticket_scope, :requires_justification, :position)
  end
end
