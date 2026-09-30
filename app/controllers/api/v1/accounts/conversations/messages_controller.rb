class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  # Editar o conteúdo é uma ação separada de atualizar o status (essa sim
  # restrita a inbox de API) — só cai no ensure_api_inbox quando o pedido é
  # de status, senão editar mensagem de um inbox normal (email/whatsapp/
  # widget) ficaria bloqueado à toa. Usa a MESMA condição (content_edit?)
  # do branch em `update` — checar coisas diferentes aqui e lá permitia um
  # pedido com `content` em branco escapar do ensure_api_inbox de um jeito
  # e do authorize de outro.
  before_action :ensure_api_inbox, only: :update, unless: :content_edit?

  def index
    @messages = message_finder.perform
  end

  def create
    user = Current.user || @resource
    mb = Messages::MessageBuilder.new(user, @conversation, params)
    @message = mb.perform
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def update
    if content_edit?
      authorize message, :update?
      content = permitted_params[:content].to_s.strip
      return render json: { error: 'Content cannot be blank' }, status: :unprocessable_entity if content.blank?

      updated = Messages::ContentUpdateService.new(
        message,
        content,
        new_attachments: permitted_params[:attachments] || [],
        remove_attachment_ids: permitted_params[:remove_attachment_ids] || []
      ).perform
      return render json: { error: 'This message cannot be edited' }, status: :unprocessable_entity unless updated
    else
      Messages::StatusUpdateService.new(message, permitted_params[:status], permitted_params[:external_error]).perform
    end
    @message = message
  end

  def destroy
    ActiveRecord::Base.transaction do
      message.update!(content: I18n.t('conversations.messages.deleted'), content_type: :text, content_attributes: { deleted: true })
      message.attachments.destroy_all
    end
  end

  def retry
    return if message.blank?

    ::SendReplyJob.perform_later(message.id) if claim_message_retry
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def translate
    return head :ok if already_translated_content_available?

    translated_content = Integrations::GoogleTranslate::ProcessorService.new(
      message: message,
      target_language: permitted_params[:target_language]
    ).perform

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations)
    end

    render json: { content: translated_content }
  rescue Google::Cloud::Error => e
    # `details` carries the clean human message; `message` includes gRPC debug noise
    render_could_not_create_error(e.details.presence || e.message)
  end

  private

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def claim_message_retry
    message.with_lock do
      next false unless message.failed?

      Messages::StatusUpdateService.new(message, 'sent').perform
      previous_source_id = message.source_id
      retry_attributes = { content_attributes: {} }
      retry_attributes[:source_id] = nil unless @conversation.inbox.api? || @conversation.inbox.web_widget?
      message.update!(retry_attributes)
      if retry_attributes.key?(:source_id) && previous_source_id.present?
        Rails.logger.info "Cleared older source ID #{previous_source_id} for message #{message.id}"
      end
      true
    end
  end

  def permitted_params
    params.permit(:id, :target_language, :status, :external_error, :content, attachments: [], remove_attachment_ids: [])
  end

  # Usa a presença da chave (não .present?) de propósito — um `content` em
  # branco/só espaço ainda precisa passar pelo authorize e pela validação
  # explícita em `update`, em vez de cair no branch de status (que aceitaria
  # silenciosamente, sem checar permissão nenhuma).
  def content_edit?
    params.key?(:content)
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end

  # API inbox check
  def ensure_api_inbox
    # Only API inboxes can update messages
    render json: { error: 'Message status update is only allowed for API inboxes' }, status: :forbidden unless @conversation.inbox.api?
  end
end
