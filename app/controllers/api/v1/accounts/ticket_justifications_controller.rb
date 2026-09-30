class Api::V1::Accounts::TicketJustificationsController < Api::V1::Accounts::BaseController
  include TicketCatalogActions

  CATALOG_MODEL = TicketJustification

  def index
    render json: { payload: catalog_scope.includes(:ticket_status_justifications).ordered }
  end

  private

  def record_params
    params.require(:ticket_justification).permit(:name, :active, :ticket_scope, :position)
  end

  def assign_associations
    return unless params[:ticket_justification].key?(:status_ids)

    @record.ticket_statuses = Current.account.ticket_statuses.where(id: params[:ticket_justification][:status_ids])
  end
end
