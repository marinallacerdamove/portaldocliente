# PATCH LOCAL (fork) - macro aplicada por agente não resolve a conversa com o
# que o botão Resolver cobra faltando (Conversations::ResolveRequirementsService):
# a ação que resolveria é pulada e o resto da macro roda, como o Chatwoot já
# faz com atributo obrigatório (Enterprise::Macros::ExecutionService). Vale
# pra resolver, pra change_status 'resolved' e pra status do cadastro que
# resolve. Macro rodada por automação (Current.executed_by) fica de fora, como
# no ResolveRequirementsGuard.
module Macros::ResolveRequirements
  def resolve_conversation(params)
    return if resolve_requirements_missing?

    super
  end

  def change_status(status)
    return if ['resolved', Conversation.statuses['resolved']].include?(status.first) && resolve_requirements_missing?

    super
  end

  def set_custom_attribute(params) # rubocop:disable Naming/AccessorMethodName -- nome da ação salvo nas macros
    key, value = params
    return if key == TicketContract::STATUS_KEY && @account.ticket_statuses.resolving.exists?(name: value) && resolve_requirements_missing?

    super
  end

  private

  def resolve_requirements_missing?
    return false if Current.executed_by.is_a?(AutomationRule)

    @conversation.reload
    !@conversation.resolved? && Conversations::ResolveRequirementsService.new(@conversation).missing.any?
  end
end
