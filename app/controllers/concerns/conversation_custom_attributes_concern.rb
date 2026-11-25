module ConversationCustomAttributesConcern
  def custom_attributes
    checklist_before = @conversation.custom_attributes&.dig(TicketContract::CUSTOM_FIELDS_KEY) || {}
    locked_before = team_locked_field_keys # PATCH LOCAL (fork)
    attributes = params.permit(custom_attributes: {})[:custom_attributes]
    # When `merge` is truthy, only the keys sent are updated and the rest are kept, matching the contacts endpoint.
    # Replace stays the default so existing integrations are unaffected.
    attributes = @conversation.custom_attributes.merge(attributes || {}) if ActiveModel::Type::Boolean.new.cast(params[:merge])
    # PATCH LOCAL (fork) - `remove` (junto com merge): chaves apagadas na mesma gravação.
    attributes = attributes.except(*params.permit(remove: [])[:remove]) if params[:remove].present?
    @conversation.custom_attributes = attributes
    keep_team_locked_fields(checklist_before, locked_before) # PATCH LOCAL (fork)
    return if ticket_status_resolve_blocked? # PATCH LOCAL (fork) - ResolveRequirementsGuard

    @conversation.save!
    log_checklist_activity(checklist_before)
  end

  def destroy_custom_attributes
    checklist_before = @conversation.custom_attributes&.dig(TicketContract::CUSTOM_FIELDS_KEY) || {}
    locked_before = team_locked_field_keys # PATCH LOCAL (fork) - apagar não passa por cima da trava de equipe
    @conversation.custom_attributes = @conversation.custom_attributes.excluding(params[:custom_attributes])
    keep_team_locked_fields(checklist_before, locked_before)
    @conversation.save!
  end

  private

  # PATCH LOCAL (fork) - campo adicional que a regra deixa só para algumas
  # equipes (Movidesk: "somente as equipes"): o valor mandado por agente de
  # fora delas é ignorado. Confere antes e depois da troca, pra mudar o serviço
  # na mesma gravação não abrir o campo. Integração e bot não passam por aqui
  # (ResolveRequirementsGuard#enforce_resolve_requirements?).
  def team_locked_field_keys
    return [] unless enforce_resolve_requirements?

    @resolve_account_data ||= Conversations::ResolveRequirementsService.account_data(Current.account)
    Conversations::ResolveRequirementsService.new(@conversation, account_data: @resolve_account_data, user: Current.user).team_locked_field_keys
  end

  def keep_team_locked_fields(before, locked_before)
    locked = locked_before | team_locked_field_keys
    return if locked.empty?

    values = (@conversation.custom_attributes || {})[TicketContract::CUSTOM_FIELDS_KEY]
    values = values.to_h if values.is_a?(ActionController::Parameters)
    values = values.is_a?(Hash) ? values.stringify_keys : {}
    kept = values.except(*locked).merge(before.slice(*locked))
    @conversation.custom_attributes = (@conversation.custom_attributes || {}).merge(TicketContract::CUSTOM_FIELDS_KEY => kept) if kept != values
  end

  # PATCH LOCAL (fork) - quem marcou o checklist vira atividade da conversa. Pela
  # integração, o Portal manda o nome de quem marcou lá (actor_name); sem nome
  # (ex. reenvio de classificação), não grava atividade.
  def log_checklist_activity(before)
    actor_name, source = portal_integration_request? ? [params[:actor_name].presence, 'portal'] : [Current.user&.name, 'chatwoot']
    return if actor_name.blank?

    Conversations::ChecklistActivityService.new(@conversation, before: before, actor_name: actor_name, source: source).perform
  end
end
