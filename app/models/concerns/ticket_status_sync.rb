# PATCH LOCAL (fork) - status do atendimento (custom_attributes.status_atendimento,
# cadastro TicketStatus) e status nativo da conversa andam juntos:
# - escolher um status do cadastro muda o status nativo pelo tipo (base);
# - mudar o nativo (resolver, reabrir, mensagem do cliente) escolhe o primeiro
#   status ativo daquele tipo, se o atual não for compatível.
# Conta sem status cadastrados não muda nada.
module TicketStatusSync
  extend ActiveSupport::Concern

  STATUS_KEY = 'status_atendimento'.freeze
  JUSTIFICATION_KEY = 'justificativa'.freeze
  # Status nativo -> tipo preferido quando o atual não combina.
  NATIVE_BASES = {
    'open' => %w[em_atendimento novo], 'pending' => %w[parado], 'snoozed' => %w[parado],
    'resolved' => %w[resolvido fechado cancelado]
  }.freeze

  included do
    before_save :sync_ticket_status
  end

  private

  def sync_ticket_status
    return unless account&.ticket_statuses&.exists?

    attributes = custom_attributes || {}
    if attributes[STATUS_KEY] != custom_attributes_was.to_h[STATUS_KEY] && !status_changed?
      apply_ticket_status(attributes[STATUS_KEY])
    elsif status_changed? || new_record?
      follow_native_status(attributes)
    end
  end

  def apply_ticket_status(name)
    ticket_status = account.ticket_statuses.find_by(name: name)
    return unless ticket_status

    self.status = ticket_status.conversation_status
    clear_invalid_justification(ticket_status)
  end

  def follow_native_status(attributes)
    current = account.ticket_statuses.find_by(name: attributes[STATUS_KEY])
    return if current && current.conversation_status == status && !new_record?

    bases = new_record? && open? ? %w[novo] : NATIVE_BASES.fetch(status, [])
    replacement = account.ticket_statuses.active.where(base: bases).ordered.min_by { |s| bases.index(s.base) }
    return unless replacement

    self.custom_attributes = attributes.merge(STATUS_KEY => replacement.name)
    clear_invalid_justification(replacement)
  end

  def clear_invalid_justification(ticket_status)
    justification = custom_attributes.to_h[JUSTIFICATION_KEY]
    return if justification.blank? || ticket_status.justifications.exists?(name: justification)

    self.custom_attributes = custom_attributes.except(JUSTIFICATION_KEY)
  end
end
