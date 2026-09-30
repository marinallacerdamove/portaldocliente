# PATCH LOCAL (fork) - comum aos cadastros de atendimento (serviço, categoria,
# status, justificativa): escopo de tipo de ticket, ordem e a lista do atributo
# de conversa correspondente, que continua sendo onde a conversa guarda o valor
# (filtros, automações, Portal e relatórios leem de lá).
module TicketCatalogItem
  extend ActiveSupport::Concern

  included do
    belongs_to :account

    enum ticket_scope: { publico: 0, interno: 1, ambos: 2 }

    validates :name, presence: true
    before_validation { self.name = name.to_s.squish }

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position, :name) }

    after_commit :sync_attribute_values
  end

  class_methods do
    # [chave do atributo de conversa, nome exibido]
    def catalog_attribute(key = nil, display_name = nil)
      @catalog_attribute = [key, display_name] if key
      @catalog_attribute
    end
  end

  def attribute_value
    name
  end

  private

  def sync_attribute_values
    key, display_name = self.class.catalog_attribute
    values = self.class.where(account_id: account_id).active.ordered.map(&:attribute_value)
    definition = account.custom_attribute_definitions.conversation_attribute.find_or_initialize_by(attribute_key: key)
    definition.attribute_display_name ||= display_name
    definition.attribute_display_type = :list
    definition.attribute_values = values
    definition.save!
  end
end
