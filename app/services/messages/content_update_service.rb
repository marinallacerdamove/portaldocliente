class Messages::ContentUpdateService
  attr_reader :message, :content

  def initialize(message, content)
    @message = message
    @content = content
  end

  def perform
    return false unless editable?

    update_message_content
  end

  private

  def update_message_content
    message.update!(content: content, content_attributes: message.content_attributes.merge(edited_at: Time.current))
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
