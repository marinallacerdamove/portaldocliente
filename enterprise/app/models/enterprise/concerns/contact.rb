module Enterprise::Concerns::Contact
  extend ActiveSupport::Concern
  included do
    belongs_to :company, optional: true, counter_cache: true
    has_many :campaign_recipients, dependent: :destroy_async

    after_commit :associate_company_from_email,
                 on: [:create, :update],
                 if: :should_associate_company?
    before_save :sync_company_name_from_company, if: :will_save_change_to_company_id?
    after_update_commit :record_company_activity, if: :saved_change_to_last_activity_at?
    # PATCH LOCAL (fork) - avisa o Portal do Cliente quando a empresa do
    # contato muda (webhook contact_company_updated), pra vincular lá também.
    after_commit :dispatch_company_updated_event, on: [:create, :update], if: :saved_change_to_company_id?
    # PATCH LOCAL (fork) - contato vinculado a uma empresa no meio do
    # atendimento preenche "Empresa" nas conversas dele ainda abertas.
    after_update_commit :fill_empresa_on_open_conversations, if: :saved_change_to_company_id?
  end

  private

  def fill_empresa_on_open_conversations
    return if company.blank?

    previous_name = Company.find_by(id: company_id_before_last_save)&.name&.strip
    conversations.where.not(status: :resolved).find_each do |conversation|
      conversation.save! if conversation.assign_empresa(company.name, replaceable: [previous_name].compact)
    end
  end

  def dispatch_company_updated_event
    Rails.configuration.dispatcher.dispatch(Events::Types::CONTACT_COMPANY_UPDATED, Time.zone.now, contact: self)
  end

  # PATCH LOCAL (fork) - associação por domínio de e-mail desligada: a
  # empresa do contato é definida pelo Portal do Cliente (vínculo por
  # CPF/CNPJ). Por domínio, todo contato @teste.com caía numa mesma empresa
  # e o company_name que o Portal mandou era sobrescrito.
  def should_associate_company?
    false
  end

  def associate_company_from_email
    Contacts::CompanyAssociationService.new.associate_company_from_email(self)
  rescue StandardError => e
    Rails.logger.error("Failed to associate company for contact #{id}: #{e.message}")
    # Don't fail the contact save if the company association fails
  end

  def record_company_activity
    company&.record_activity_at!(last_activity_at) if last_activity_at.present?
  end

  def sync_company_name_from_company
    self.additional_attributes ||= {}

    if company_id.present?
      additional_attributes['company_name'] = company&.name
    else
      additional_attributes.delete('company_name')
    end
  end
end
