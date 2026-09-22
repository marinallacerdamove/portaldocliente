# Substitui {{variavel}} (capturadas pelo fluxo) e {{contact.*}}/{{conversation.*}}
# num texto - usado em mensagens, corpo de webhook e URL dos nós do BotFlow.
module BotFlows::Interpolation
  def self.render(template, variables:, contact: nil, conversation: nil)
    return template if template.blank?

    contact ||= conversation&.contact
    template.gsub(/\{\{([\w.-]+)\}\}/) { resolve(Regexp.last_match(1), variables, contact, conversation).to_s }
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
