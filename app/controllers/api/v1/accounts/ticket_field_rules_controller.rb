class Api::V1::Accounts::TicketFieldRulesController < Api::V1::Accounts::BaseController
  include TicketCatalogActions

  CATALOG_MODEL = TicketFieldRule

  private

  def record_params
    params.require(:ticket_field_rule).permit(
      :name, :active, :position,
      conditions: [:group, :attribute, :operator, :value, :field_id],
      fields: [:field_id, :columns, :visible_to_clients, :editable_by_clients, :editable_by_agents, :required_on]
    )
  end
end
