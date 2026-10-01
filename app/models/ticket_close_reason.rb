# PATCH LOCAL (fork) - motivo de encerramento, pedido pelo Resolver
# (ResolveAction.vue). A conversa guarda o nome em
# custom_attributes.motivo_encerramento; o Portal casa pelo mesmo nome.
class TicketCloseReason < ApplicationRecord
  include TicketCatalogItem

  catalog_attribute 'motivo_encerramento', 'Motivo de encerramento'

  validates :name, uniqueness: { scope: :account_id }

  def as_json(*)
    slice(:id, :name, :active, :ticket_scope, :position)
  end
end
