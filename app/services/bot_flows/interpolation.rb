# Substitui {{variavel}} (capturadas pelo fluxo) e {{contact.*}}/{{conversation.*}}
# num texto - usado em mensagens, corpo de webhook e URL dos nós do BotFlow.
module BotFlows::Interpolation
  # escape: :liquid - o texto vira mensagem outgoing, que o Liquidable renderiza
  # como template Liquid; o valor (resposta do cliente, nome do perfil,
  # retorno de webhook) não pode virar código Liquid.
  # escape: :json - o valor vai dentro de uma string JSON do corpo do webhook, escapado para o
  # texto do cliente não fechar a string e acrescentar campos (B83).
  def self.render(template, variables:, contact: nil, conversation: nil, escape: nil)
    return template if template.blank?

    contact ||= conversation&.contact
    template.gsub(/\{\{([\w.-]+)\}\}/) do
      value = resolve(Regexp.last_match(1), variables, contact, conversation).to_s
      case escape
      when :json then value.to_json[1..-2]
      when :liquid then liquid_literal(value)
      else value
      end
    end
  end

  # Troca o "{" que abriria {{ ou {% (ou que fica no fim e emendaria no
  # texto seguinte) por {{ '{' }}, que o Liquid renderiza de volta como "{".
  def self.liquid_literal(value)
    value.gsub(/\{(?=[{%]|\z)/, "{{ '{' }}")
  end

  def self.resolve(key, variables, contact, conversation)
    return variables[key] if variables.key?(key)

    case key
    when /\Acontact\.custom_attributes\.(.+)\z/ then contact&.custom_attributes&.[](::Regexp.last_match(1))
    when 'contact.name' then contact&.name
    when 'contact.email' then contact&.email
    when 'contact.phone_number' then contact&.phone_number
    when 'contact.identifier' then contact&.identifier
    when /\Aconversation\.custom_attributes\.(.+)\z/ then conversation&.custom_attributes&.[](::Regexp.last_match(1))
    when 'conversation.id' then conversation&.display_id
    when 'conversation.status' then conversation&.status
    when 'conversation.priority' then conversation&.priority
    when 'inbox.name' then conversation&.inbox&.name
    when 'agent.name' then conversation&.assignee&.name
    when 'agent.email' then conversation&.assignee&.email
    end
  end
end
