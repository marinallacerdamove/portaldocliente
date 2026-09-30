# PATCH LOCAL (fork) - status do ticket (Movidesk: Status). O tipo (base) diz
# qual status nativo do Chatwoot a conversa assume.
class TicketStatus < ApplicationRecord
  include TicketCatalogItem

  CONVERSATION_STATUS = {
    'novo' => 'open', 'em_atendimento' => 'open', 'parado' => 'pending',
    'resolvido' => 'resolved', 'fechado' => 'resolved', 'cancelado' => 'resolved'
  }.freeze

  catalog_attribute 'status_atendimento', 'Status'

  has_many :ticket_status_justifications, dependent: :destroy
  has_many :justifications, through: :ticket_status_justifications, source: :ticket_justification

  validates :name, uniqueness: { scope: :account_id }
  validates :base, inclusion: { in: CONVERSATION_STATUS.keys }

  def conversation_status
    CONVERSATION_STATUS.fetch(base)
  end

  def as_json(*)
    slice(:id, :name, :base, :active, :ticket_scope, :requires_justification, :position)
  end
end
