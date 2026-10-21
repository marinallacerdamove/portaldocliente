# PATCH LOCAL (fork) - comum aos cadastros de atendimento (serviço, categoria,
# status, justificativa, motivo de encerramento): escopo de tipo de ticket,
# ordem, código de negócio e a lista do atributo de conversa correspondente,
# que continua sendo onde a conversa guarda o valor (filtros, automações,
# Portal e relatórios leem de lá).
#
# Código (`code`, TicketCatalogCode) e evento para o Portal (TicketCatalogPortalEvent)
# são comuns também ao campo adicional e à regra de exibição.
module TicketCatalogItem
  extend ActiveSupport::Concern

  included do
    include TicketCatalogRename
    include TicketCatalogCode
    include TicketCatalogPortalEvent

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

    # Nome único sem diferenciar maiúscula de minúscula (o índice do banco continua
    # exato). Só confere quando o nome (ou o escopo) muda ou o item é novo: dado
    # antigo com nomes que diferem só pela caixa continua salvando outros campos.
    def unique_catalog_name(scope: :account_id)
      watched = [:name, *Array(scope)]
      validates :name, uniqueness: { scope: scope, case_sensitive: false },
                       if: -> { new_record? || watched.any? { |attribute| will_save_change_to_attribute?(attribute) } }
    end

    # Item que a conversa aponta pelo valor guardado em custom_attributes.
    def for_attribute_value(value)
      find_by(name: value)
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
