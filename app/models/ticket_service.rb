# PATCH LOCAL (fork) - serviço do ticket em árvore (Movidesk: Serviços). Interno
# (visible_to_clients: false) só aparece pra agente; no Portal, cliente não vê.
class TicketService < ApplicationRecord
  include TicketCatalogItem

  PATH_SEPARATOR = ' › '.freeze

  catalog_attribute 'servico', 'Serviço'

  belongs_to :parent, class_name: 'TicketService', optional: true
  has_many :children, class_name: 'TicketService', foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  belongs_to :default_category, class_name: 'TicketCategory', optional: true
  belongs_to :macro, optional: true
  has_many :ticket_service_categories, dependent: :destroy
  has_many :categories, through: :ticket_service_categories, source: :ticket_category

  validates :name, uniqueness: { scope: %i[account_id parent_id] }
  validates :default_priority, inclusion: { in: TicketCategory::PRIORITIES }, allow_blank: true
  validate :parent_in_account_without_cycle
  validate :macro_shared

  before_validation { self.default_priority = default_priority.presence }

  # Mesmo formato que a conversa guarda em custom_attributes.servico.
  def full_name
    [*parent&.full_name, name].join(PATH_SEPARATOR)
  end

  def attribute_value
    full_name
  end

  def as_json(*)
    slice(:id, :parent_id, :name, :description, :active, :ticket_scope, :visible_to_clients, :allow_finish,
          :all_categories, :default_category_id, :default_priority, :macro_id, :position)
      .merge(full_name: full_name, category_ids: ticket_service_categories.map(&:ticket_category_id))
  end

  private

  def parent_in_account_without_cycle
    return unless parent

    errors.add(:parent_id, :invalid) if parent.account_id != account_id
    node = parent
    while node
      return errors.add(:parent_id, :invalid) if node.id == id

      node = node.parent
    end
  end

  # Macro pessoal não pode rodar pra quem escolhe o serviço.
  def macro_shared
    errors.add(:macro_id, :invalid) if macro && (macro.account_id != account_id || macro.personal?)
  end
end
