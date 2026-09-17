# Ações do nó "Ação do Chatwoot" - reaproveita ActionService (mesmas
# checagens de segurança que Automação/Macros já usam) e só adiciona o que
# falta pra esse nó (definir atributo personalizado da conversa).
class BotFlows::ActionExecutor < ActionService
  def set_custom_attribute(params)
    key, value = params
    return if key.blank?

    @conversation.update!(custom_attributes: @conversation.custom_attributes.merge(key => value))
  end
end
