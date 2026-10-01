module ConversationCustomAttributesConcern
  def custom_attributes
    checklist_before = @conversation.custom_attributes&.dig('campos_adicionais') || {}
    attributes = params.permit(custom_attributes: {})[:custom_attributes]
    # When `merge` is truthy, only the keys sent are updated and the rest are kept, matching the contacts endpoint.
    # Replace stays the default so existing integrations are unaffected.
    attributes = @conversation.custom_attributes.merge(attributes || {}) if ActiveModel::Type::Boolean.new.cast(params[:merge])
    @conversation.custom_attributes = attributes
    @conversation.save!
    log_checklist_activity(checklist_before)
  end

  def destroy_custom_attributes
    @conversation.custom_attributes = @conversation.custom_attributes.excluding(params[:custom_attributes])
    @conversation.save!
  end

  private

  # PATCH LOCAL (fork) - quem marcou o checklist vira atividade da conversa. Pela
  # integração, o Portal manda o nome de quem marcou lá (actor_name); sem nome
  # (ex. reenvio de classificação), não grava atividade.
  def log_checklist_activity(before)
    actor_name, source = portal_integration_request? ? [params[:actor_name].presence, 'portal'] : [Current.user&.name, 'chatwoot']
    return if actor_name.blank?

    Conversations::ChecklistActivityService.new(@conversation, before: before, actor_name: actor_name, source: source).perform
  end
end
