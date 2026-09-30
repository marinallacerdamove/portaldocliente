# PATCH LOCAL (fork) - status em que a justificativa pode ser usada.
class TicketStatusJustification < ApplicationRecord
  belongs_to :ticket_status
  belongs_to :ticket_justification
end
