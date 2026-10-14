# PATCH LOCAL (fork) - serviço do ticket em árvore (Movidesk: Serviços). Interno
# (visible_to_clients: false) só aparece pra agente; no Portal, cliente não vê.
class TicketService < ApplicationRecord
  include TicketCatalogItem

  PATH_SEPARATOR = ' › '.freeze

  catalog_attribute TicketContract::SERVICE_KEY, 'Serviço'

  belongs_to :parent, class_name: 'TicketService', optional: true
  has_many :children, class_name: 'TicketService', foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  belongs_to :default_category, class_name: 'TicketCategory', optional: true
  belongs_to :macro, optional: true
  has_many :ticket_service_categories, dependent: :destroy
  has_many :categories, through: :ticket_service_categories, source: :ticket_category

  unique_catalog_name scope: %i[account_id parent_id]
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

  # Serviço guardado na conversa é o caminho completo: acha pelo último nome e confere o caminho.
  def self.for_attribute_value(value)
    where(name: value.to_s.split(PATH_SEPARATOR).last).detect { |service| service.full_name == value }
  end

  def as_json(*)
    slice(:id, :code, :parent_id, :name, :description, :active, :ticket_scope, :visible_to_clients, :allow_finish,
          :all_categories, :default_category_id, :default_priority, :macro_id, :position)
      .merge(full_name: full_name, category_ids: ticket_service_categories.map(&:ticket_category_id))
  end

  private

  # Renomear ou mover um serviço muda o caminho de toda a subárvore: [[id, caminho antigo, caminho novo]].
  def catalog_rename_entries
    old_parent = TicketService.find_by(id: parent_id_before_last_save)
    old_path = [*old_parent&.full_name, name_before_last_save].join(PATH_SEPARATOR)
    new_path = full_name
    children_by_parent = TicketService.where(account_id: account_id).pluck(:id, :parent_id, :name).group_by(&:second)
    entries = [[id, old_path, new_path]]
    queue = [[id, old_path, new_path]]
    while (parent_entry = queue.shift)
      children_by_parent.fetch(parent_entry.first, []).each do |child_id, _parent_id, child_name|
        child_entry = [child_id, [parent_entry.second, child_name].join(PATH_SEPARATOR), [parent_entry.third, child_name].join(PATH_SEPARATOR)]
        entries << child_entry
        queue << child_entry
      end
    end
    entries
  end

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
