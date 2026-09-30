class Api::V1::Accounts::TicketServicesController < Api::V1::Accounts::BaseController
  include TicketCatalogActions

  CATALOG_MODEL = TicketService

  def index
    render json: { payload: catalog_scope.includes(:parent, :ticket_service_categories).ordered }
  end

  private

  def record_params
    params.require(:ticket_service).permit(:name, :description, :parent_id, :active, :ticket_scope, :visible_to_clients,
                                           :allow_finish, :all_categories, :default_category_id, :default_priority,
                                           :macro_id, :position)
  end

  def assign_associations
    return unless params[:ticket_service].key?(:category_ids)

    @record.categories = Current.account.ticket_categories.where(id: params[:ticket_service][:category_ids])
  end
end
