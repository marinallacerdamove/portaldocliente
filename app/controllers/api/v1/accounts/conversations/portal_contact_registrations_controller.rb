# PATCH LOCAL (fork) - "Cadastrar contato": completa o contato do Chatwoot e/ou
# cadastra o solicitante como usuário do Portal (PortalContacts::Client).
class Api::V1::Accounts::Conversations::PortalContactRegistrationsController < Api::V1::Accounts::Conversations::BaseController
  rescue_from PortalContacts::Client::Error do |e|
    Rails.logger.error("[PortalContacts] #{e.message}")
    render json: { error: I18n.t('portal_contact_registration.portal_unreachable') }, status: :bad_gateway
  end

  def create
    contact = @conversation.contact
    return render_error(I18n.t('portal_contact_registration.choose_one')) unless complete_chatwoot? || register_portal?

    complete_chatwoot_contact!(contact) if complete_chatwoot?
    return render json: { contact_updated: complete_chatwoot? } unless register_portal?

    register_in_portal(contact.reload)
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages.to_sentence)
  end

  private

  def complete_chatwoot?
    ActiveModel::Type::Boolean.new.cast(params[:complete_chatwoot])
  end

  def register_portal?
    ActiveModel::Type::Boolean.new.cast(params[:register_portal])
  end

  # Só preenche o que veio preenchido: nunca apaga dado do contato.
  def complete_chatwoot_contact!(contact)
    authorize contact, :update?
    attributes = { name: params[:name], email: params[:email], phone_number: params[:phone] }.compact_blank
    contact.update!(attributes) if attributes.any?
  end

  def register_in_portal(contact)
    return render_error(I18n.t('portal_contact_registration.company_required')) if contact.company_id.blank?

    response = PortalContacts::Client.new(account: Current.account)
                                     .register(contact: contact, conversation: @conversation, **registration_fields(contact))
    return render json: response.body.merge(contact_updated: complete_chatwoot?) if response.status.between?(200, 299)

    render_portal_failure(response)
  end

  # O que foi digitado vale; o que ficou em branco vem do contato.
  def registration_fields(contact)
    { name: params[:name].presence || contact.name, email: params[:email].presence || contact.email,
      phone: params[:phone].presence || contact.phone_number }
  end

  def render_portal_failure(response)
    message = response.body['error'].presence || I18n.t('portal_contact_registration.portal_unreachable')
    render_error(message, response.status == 422 ? :unprocessable_entity : :bad_gateway)
  end

  def render_error(message, status = :unprocessable_entity)
    render json: { error: message }, status: status
  end
end
