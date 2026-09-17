# Substitui {{variavel}} (capturadas pelo fluxo) e {{contact.*}} num texto -
# usado em mensagens, corpo de webhook e URL dos nós do BotFlow.
module BotFlows::Interpolation
  def self.render(template, variables:, contact: nil)
    return template if template.blank?

    variables.reduce(template.dup) { |acc, (key, value)| acc.gsub("{{#{key}}}", value.to_s) }
             .gsub('{{contact.name}}', contact&.name.to_s)
             .gsub('{{contact.email}}', contact&.email.to_s)
             .gsub('{{contact.phone_number}}', contact&.phone_number.to_s)
  end
end
