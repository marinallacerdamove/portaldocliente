class Messages::ContentUpdateService
  include ::FileTypeHelper

  attr_reader :message, :content, :new_attachments, :remove_attachment_ids

  def initialize(message, content, new_attachments: [], remove_attachment_ids: [])
    @message = message
    @content = content
    @new_attachments = new_attachments
    @remove_attachment_ids = remove_attachment_ids
  end

  def perform
    return false unless editable?

    update_message_content
    remove_attachments
    add_attachments
    message
  end

  private

  def update_message_content
    message.update!(content: content, content_attributes: message.content_attributes.merge(edited_at: Time.current))
  end

  def remove_attachments
    return if remove_attachment_ids.blank?

    message.attachments.where(id: remove_attachment_ids).destroy_all
  end

  # Mesmo padrão do Messages::MessageBuilder#process_attachments (mensagem
  # nova) - reaproveita FileTypeHelper#file_type pra manter o mesmo
  # mapeamento de content_type -> file_type (image/file/audio/video) usado
  # em qualquer outro upload do Chatwoot.
  def add_attachments
    return if new_attachments.blank?

    new_attachments.each do |uploaded_attachment|
      attachment = message.attachments.build(account_id: message.account_id, file: uploaded_attachment)
      attachment.file_type = file_type(uploaded_attachment&.content_type)
    end
    message.save!
  end

  # Só réplica pública ou nota interna de agente (message_type outgoing cobre
  # os dois) pode ser editada — nunca o que o próprio contato escreveu
  # (incoming), nem mensagem de atividade/sistema, nem uma já apagada. E só
  # content_type text: CSAT/formulário/ligação de voz guardam o payload real
  # em content_attributes (items/submitted_values/etc.) — editar só o texto
  # exibido deixaria a pergunta mostrada sem relação com o que foi respondido.
  def editable?
    message.outgoing? && message.text? && !message.deleted
  end
end
