class MessageContentPresenter < SimpleDelegator
  def outgoing_content
    Messages::MarkdownRendererService.new(
      content_for_delivery,
      conversation.inbox.channel_type,
      conversation.inbox.channel
    ).render
  end

  # Canais de API (ex.: integrações externas como o Portal do Cliente) não
  # têm um renderizador próprio de entrega (diferente de e-mail/WhatsApp/
  # etc., que já têm um serviço de "send"), então o único lugar onde o
  # conteúdo chega até eles é esse webhook genérico. Sem isso, imagem/negrito
  # da assinatura do agente chegavam como markdown cru (`![arquivo.png](url)`,
  # `**negrito**`) em vez de HTML de verdade.
  def webhook_content
    return outgoing_content if conversation.inbox.channel_type == 'Channel::Api'

    Messages::WebhookContentNormalizer.normalize(content_with_survey_link)
  end

  private

  # Identifica o agente humano que respondeu, em markdown, antes do render
  # por canal (assim cada canal formata o negrito do próprio jeito: WhatsApp
  # vira *Nome*, e-mail/Portal viram <strong>). O Portal já mostra o nome do
  # remetente no cabeçalho de cada mensagem, então fica de fora aqui pra não
  # duplicar.
  def content_for_delivery
    text = content_with_survey_link
    return text unless prepend_sender_name?(text)

    "**#{sender.name}**: #{text}"
  end

  def prepend_sender_name?(text)
    text.present? && sender.is_a?(User) && conversation.inbox.channel_type != 'Channel::Api'
  end

  def content_with_survey_link
    if should_append_survey_link?
      survey_link = survey_url(conversation.uuid)
      custom_message = inbox.csat_config&.dig('message')
      custom_message.present? ? "#{custom_message} #{survey_link}" : I18n.t('conversations.survey.response', link: survey_link)
    else
      content
    end
  end

  def should_append_survey_link?
    input_csat? && !inbox.web_widget?
  end

  def survey_url(conversation_uuid)
    "#{ENV.fetch('FRONTEND_URL', nil)}/survey/responses/#{conversation_uuid}"
  end
end
