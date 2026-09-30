# PATCH LOCAL (fork) - justificativa do status (Movidesk: Justificativas).
class TicketJustification < ApplicationRecord
  include TicketCatalogItem

  catalog_attribute 'justificativa', 'Justificativa'

  has_many :ticket_status_justifications, dependent: :destroy
  has_many :ticket_statuses, through: :ticket_status_justifications

  validates :name, uniqueness: { scope: :account_id }

  def as_json(*)
    slice(:id, :name, :active, :ticket_scope, :position).merge(status_ids: ticket_status_justifications.map(&:ticket_status_id))
  end
end
