# PATCH LOCAL (fork) - justificativa do status (Movidesk: Justificativas).
class TicketJustification < ApplicationRecord
  include TicketCatalogItem

  catalog_attribute TicketContract::JUSTIFICATION_KEY, 'Justificativa'

  has_many :ticket_status_justifications, dependent: :destroy
  has_many :ticket_statuses, through: :ticket_status_justifications

  unique_catalog_name

  def as_json(*)
    slice(:id, :code, :name, :active, :ticket_scope, :position).merge(status_ids: ticket_status_justifications.map(&:ticket_status_id))
  end
end
