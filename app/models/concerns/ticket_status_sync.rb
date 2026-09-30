# PATCH LOCAL (fork) - status do atendimento (custom_attributes.status_atendimento,
# cadastro TicketStatus) e status nativo da conversa andam juntos, em qualquer
# canal e em qualquer caminho (botão, automação, API, mensagem do cliente):
# - escolher um status do cadastro muda o status nativo pelo tipo (base);
# - mudar o nativo (resolver, reabrir, mensagem do cliente) escolhe o primeiro
#   status ativo daquele tipo, se o atual não for compatível;
# - status vazio (ex.: tela salvando custom_attributes desatualizados) volta
#   pro padrão do status nativo atual - conversa nunca fica sem status.
# Conta sem status cadastrados não muda nada disso.
# Independente do cadastro: reabrir limpa o motivo de encerramento, que vale
# só pra resolução atual - assim o próximo Resolver pergunta de novo.
module TicketStatusSync
  extend ActiveSupport::Concern

  STATUS_KEY = 'status_atendimento'.freeze
  JUSTIFICATION_KEY = 'justificativa'.freeze
  CLOSE_REASON_KEY = 'motivo_encerramento'.freeze
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
    clear_close_reason_on_reopen
    return unless account&.ticket_statuses&.exists?

    if ticket_status_picked?
      apply_ticket_status(custom_attributes[STATUS_KEY])
    elsif follow_native_status?
      follow_native_status
    end
  end

  def follow_native_status?
    status_changed? || new_record? || custom_attributes.to_h[STATUS_KEY].blank?
  end

  # Status escolhido (lista, automação, API) sem mexer no nativo no mesmo save.
  def ticket_status_picked?
    value = custom_attributes.to_h[STATUS_KEY]
    value.present? && value != custom_attributes_was.to_h[STATUS_KEY] && !status_changed?
  end

  def clear_close_reason_on_reopen
    return unless status_changed? && status_was == 'resolved'
    return unless custom_attributes.to_h.key?(CLOSE_REASON_KEY)

    self.custom_attributes = custom_attributes.except(CLOSE_REASON_KEY)
  end

  def apply_ticket_status(name)
    ticket_status = account.ticket_statuses.find_by(name: name)
    return unless ticket_status

    self.status = ticket_status.conversation_status
    clear_invalid_justification(ticket_status)
  end

  def follow_native_status
    current = account.ticket_statuses.find_by(name: custom_attributes.to_h[STATUS_KEY])
    return if current&.conversation_status == status && !new_record?

    replacement = default_ticket_status
    return unless replacement

    self.custom_attributes = custom_attributes.to_h.merge(STATUS_KEY => replacement.name)
    clear_invalid_justification(replacement)
  end

  def default_ticket_status
    bases = new_record? && open? ? %w[novo] : NATIVE_BASES.fetch(status, [])
    account.ticket_statuses.active.where(base: bases).ordered.min_by { |s| bases.index(s.base) }
  end

  def clear_invalid_justification(ticket_status)
    justification = custom_attributes.to_h[JUSTIFICATION_KEY]
    return if justification.blank? || ticket_status.justifications.exists?(name: justification)

    self.custom_attributes = custom_attributes.except(JUSTIFICATION_KEY)
  end
end
