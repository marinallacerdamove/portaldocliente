# PATCH LOCAL (fork) - motivo de encerramento, pedido pelo Resolver
# (ResolveAction.vue). A conversa guarda o nome em
# custom_attributes.motivo_encerramento; o Portal casa pelo mesmo nome.
class TicketCloseReason < ApplicationRecord
  include TicketCatalogItem

  catalog_attribute TicketContract::CLOSE_REASON_KEY, 'Motivo de encerramento'

  unique_catalog_name

  def as_json(*)
    slice(:id, :code, :name, :active, :ticket_scope, :position)
  end
end
