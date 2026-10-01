# PATCH LOCAL (fork) - trava do Resolver no servidor (ver
# Conversations::ResolveRequirementsService). Vale pra agente pela tela. Fica
# de fora a integração: o Portal resolve pelo token do usuário em
# PORTAL_INTEGRATION_USER_EMAIL (o cliente fecha ticket no Portal sem ver
# campo interno), e automação/bot não é User. Sem a variável, nenhum acesso
# por token é travado - nunca quebra o sync do Portal por falta de config.
module ResolveRequirementsGuard
  private

  def enforce_resolve_requirements?
    Current.user.is_a?(User) && !portal_integration_request?
  end

  def portal_integration_request?
    return false unless authenticate_by_access_token?

    integration_email = ENV.fetch('PORTAL_INTEGRATION_USER_EMAIL', '').strip
    integration_email.blank? || Current.user&.email&.casecmp?(integration_email)
  end

  def resolve_requirements_missing(conversation)
    return [] if conversation.resolved? || !enforce_resolve_requirements?

    Conversations::ResolveRequirementsService.new(conversation).missing
  end
end
