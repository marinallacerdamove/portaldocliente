# PATCH LOCAL (fork) - categoria do ticket (Movidesk: Categorias).
class TicketCategory < ApplicationRecord
  include TicketCatalogItem

  PRIORITIES = %w[low medium high urgent].freeze

  catalog_attribute TicketContract::CATEGORY_KEY, 'Tipo de solicitação'

  has_many :ticket_service_categories, dependent: :destroy
  has_many :ticket_services, through: :ticket_service_categories

  unique_catalog_name
  validate :priorities_known

  before_validation { self.allowed_priorities = Array(allowed_priorities).compact_blank.uniq }

  def as_json(*)
    slice(:id, :code, :name, :active, :ticket_scope, :allowed_priorities, :position)
  end

  private

  def priorities_known
    errors.add(:allowed_priorities, :invalid) if (allowed_priorities - PRIORITIES).any?
  end
end
