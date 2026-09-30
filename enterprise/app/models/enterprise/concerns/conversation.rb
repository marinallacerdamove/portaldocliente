module Enterprise::Concerns::Conversation
  extend ActiveSupport::Concern

  included do
    belongs_to :sla_policy, optional: true
    has_one :applied_sla, dependent: :destroy_async
    has_many :sla_events, dependent: :destroy_async
    has_many :calls, dependent: :destroy_async
    has_many :captain_responses, class_name: 'Captain::AssistantResponse', dependent: :nullify, as: :documentable
    has_many :captain_faq_observations, class_name: 'Captain::FaqObservation', dependent: :delete_all
    has_many :conversation_outcomes, dependent: :destroy_async
    scope :with_sla_applicable_contact, -> { left_joins(:contact).where(contacts: { blocked: [false, nil] }) }

    before_validation :validate_sla_policy, if: -> { sla_policy_id_changed? }
    around_save :ensure_applied_sla_is_created, if: -> { sla_policy_id_changed? }
    # PATCH LOCAL (fork) - "Empresa" (Ações da conversa) já nasce com a empresa
    # do contato, em qualquer canal.
    before_create :fill_empresa_from_contact_company
  end

  def sla_applicable?
    !contact&.blocked?
  end

  # PATCH LOCAL (fork) - só preenche vazio; `replaceable` são valores que
  # podem ser trocados (ex.: empresa anterior do contato, preenchida sozinha).
  def assign_empresa(name, replaceable: [])
    name = name.to_s.strip
    current = (custom_attributes || {})['empresa'].presence
    return false if name.blank? || current == name
    return false if current && replaceable.exclude?(current)

    self.custom_attributes = (custom_attributes || {}).merge('empresa' => name)
    true
  end

  private

  def fill_empresa_from_contact_company
    assign_empresa(contact&.company&.name)
  end

  def validate_sla_policy
    # TODO: remove these validations once we figure out how to deal with these cases
    if sla_policy_id.nil? && changes[:sla_policy_id].first.present?
      errors.add(:sla_policy, 'cannot remove sla policy from conversation')
      return
    end

    unless sla_applicable?
      errors.add(:sla_policy, 'cannot be assigned to conversations with blocked contacts')
      return
    end

    if changes[:sla_policy_id].first.present?
      errors.add(:sla_policy, 'conversation already has a different sla')
      return
    end

    errors.add(:sla_policy, 'sla policy account mismatch') if sla_policy&.account_id != account_id
  end

  # handling inside a transaction to ensure applied sla record is also created
  def ensure_applied_sla_is_created
    ActiveRecord::Base.transaction do
      yield
      create_applied_sla(sla_policy_id: sla_policy_id) if applied_sla.blank?
    end
  rescue ActiveRecord::RecordInvalid
    raise ActiveRecord::Rollback
  end
end
