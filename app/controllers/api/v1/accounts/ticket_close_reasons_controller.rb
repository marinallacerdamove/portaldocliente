class Api::V1::Accounts::TicketCloseReasonsController < Api::V1::Accounts::BaseController
  include TicketCatalogActions

  CATALOG_MODEL = TicketCloseReason

  private

  def record_params
    params.require(:ticket_close_reason).permit(:name, :active, :position)
  end
end
