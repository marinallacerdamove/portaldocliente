# PATCH LOCAL (fork) - categorias permitidas de um serviço.
class TicketServiceCategory < ApplicationRecord
  belongs_to :ticket_service
  belongs_to :ticket_category
end
