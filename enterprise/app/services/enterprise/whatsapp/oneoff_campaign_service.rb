module Enterprise::Whatsapp::OneoffCampaignService
  def perform
    validate_campaign!
    recipients = portal_retryable { create_recipients }
    process_recipients(recipients)
    campaign.completed!
  end

  private

  def process_recipient(recipient)
    contact = recipient.contact
    Rails.logger.info "Processing contact: #{contact.name} (#{contact.phone_number})"

    if contact.phone_number.blank?
      Rails.logger.info "Skipping contact #{contact.name} - no phone number"
      recipient.mark_skipped!('Phone number is missing')
      return
    end

    if campaign.template_params.blank?
      Rails.logger.error "Skipping contact #{contact.name} - no template_params found for WhatsApp campaign"
      recipient.mark_skipped!('Template parameters are missing')
      return
    end

    processed_template_params = process_liquid_template_params(contact)
    if processed_template_params.nil?
      recipient.mark_skipped!('Template parameters could not be resolved')
      return
    end

    recipient.update!(message_content: rendered_message_content(contact))

    send_whatsapp_template_message(recipient: recipient, to: contact.phone_number, template_params: processed_template_params)
  end

  # PATCH LOCAL (fork) - Portal fora do ar ao montar o público: nada foi
  # enviado ainda, então a campanha volta pra ativa e a varredura agendada
  # (TriggerScheduledItemsJob) tenta de novo, em vez de ficar presa em
  # "processando". O erro continua subindo (log/GlitchTip).
  def portal_retryable
    yield
  rescue PortalGroups::Client::Error
    campaign.update!(campaign_status: :active, started_at: nil)
    raise
  end

  # PATCH LOCAL (fork) - o público (etiquetas + Grupos do Portal) vem de audience_contacts (OSS).
  def create_recipients
    contacts = audience_contacts
    Rails.logger.info "Processing #{contacts.count} contacts for campaign #{campaign.id}"

    contacts.find_each.map do |contact|
      campaign.campaign_recipients.find_or_create_by!(contact: contact) do |recipient|
        recipient.account = campaign.account
        recipient.inbox = campaign.inbox
      end
    end
  end

  def process_recipients(recipients)
    recipients.each { |recipient| process_recipient(recipient) }

    Rails.logger.info "Campaign #{campaign.id} processing completed"
  end

  def rendered_message_content(contact)
    Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact).call(campaign.message)
  end

  def send_whatsapp_template_message(recipient:, to:, template_params:)
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params
    )

    name, namespace, lang_code, processed_parameters = processor.call

    if name.blank?
      recipient.mark_skipped!('Template name could not be resolved')
      return
    end

    source_id = channel.send_template(to, template_info(name, namespace, lang_code, processed_parameters), nil)

    update_recipient_from_provider_response(recipient, source_id)
  rescue StandardError => e
    Rails.logger.error "Failed to send WhatsApp template message to #{to}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
    recipient.mark_failed!(message: e.message)
    # continue processing remaining contacts
    nil
  end

  def template_info(name, namespace, lang_code, processed_parameters)
    {
      name: name,
      namespace: namespace,
      lang_code: lang_code,
      parameters: processed_parameters
    }
  end

  def update_recipient_from_provider_response(recipient, source_id)
    if source_id.present?
      recipient.mark_sent!(source_id)
    else
      recipient.mark_failed!(channel.last_provider_error || { message: 'WhatsApp provider did not return a message id' })
    end
  end
end
