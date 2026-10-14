# PATCH LOCAL (fork) - comum aos cadastros de atendimento (serviço, categoria,
# status, justificativa, motivo de encerramento): escopo de tipo de ticket,
# ordem, código de negócio e a lista do atributo de conversa correspondente,
# que continua sendo onde a conversa guarda o valor (filtros, automações,
# Portal e relatórios leem de lá).
#
# Código (`code`): identidade de negócio do item, dona do Portal do Cliente
# (SRV-0042, TIP-0007...). Nasce nulo; vai de nulo para um valor uma única vez e
# nunca mais muda. NÃO entra por atribuição em massa nem pela API de admin
# (`code=` é privado): o único caminho é `assign_code`, usado pelo endpoint de
# sincronização com o Portal.
module TicketCatalogItem
  extend ActiveSupport::Concern

  CODE_FORMAT = /\A[A-Z0-9]+(-[A-Z0-9]+)*\z/
  CODE_MAX_LENGTH = 32

  included do
    include TicketCatalogRename

    belongs_to :account

    enum ticket_scope: { publico: 0, interno: 1, ambos: 2 }

    validates :name, presence: true
    validates :code, format: { with: CODE_FORMAT }, length: { maximum: CODE_MAX_LENGTH },
                     uniqueness: { scope: :account_id }, allow_nil: true, if: :will_save_change_to_code?
    validate :code_never_changes

    before_validation { self.name = name.to_s.squish }
    before_validation { self.code = code.to_s.strip.presence }

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

  # Caminho do endpoint de sincronização: grava o código (nulo -> valor) sem
  # abrir `code=` pra atribuição em massa. A validação recusa trocar um código
  # que já existe.
  def assign_code(value)
    self.code = value
  end

  private

  def code=(value)
    self[:code] = value
  end

  def code_never_changes
    return unless persisted? && will_save_change_to_code? && code_in_database.present?

    errors.add(:code, :immutable, message: 'cannot be changed once set')
  end

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
