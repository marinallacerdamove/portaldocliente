# PATCH LOCAL (fork) - status do ticket (Movidesk: Status). O tipo (base) diz
# qual status nativo do Chatwoot a conversa assume.
class TicketStatus < ApplicationRecord
  include TicketCatalogItem

  CONVERSATION_STATUS = {
    'novo' => 'open', 'em_atendimento' => 'open', 'parado' => 'pending',
    'resolvido' => 'resolved', 'fechado' => 'resolved', 'cancelado' => 'resolved'
  }.freeze

  catalog_attribute TicketContract::STATUS_KEY, 'Status'

  has_many :ticket_status_justifications, dependent: :destroy
  has_many :justifications, through: :ticket_status_justifications, source: :ticket_justification

  validates :name, uniqueness: { scope: :account_id }
  validates :base, inclusion: { in: CONVERSATION_STATUS.keys }

  scope :resolving, -> { where(base: CONVERSATION_STATUS.filter_map { |base, status| base if status == 'resolved' }) }

  def conversation_status
    CONVERSATION_STATUS.fetch(base)
  end

  def as_json(*)
    slice(:id, :name, :base, :active, :ticket_scope, :requires_justification, :position).merge(conversation_status: conversation_status)
  end
end
