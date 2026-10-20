module EnsureCurrentAccountHelper
  private

  def current_account
    @current_account ||= ensure_current_account
    Current.account = @current_account
  end

  def ensure_current_account
    Current.acting_user = nil
    account = Account.find(params[:account_id])
    render_unauthorized('Account is suspended') and return unless account.active?

    if current_user
      account_accessible_for_user?(account)
    elsif @resource.is_a?(AgentBot)
      account_accessible_for_bot?(account)
    else
      render_unauthorized(I18n.t('errors.account.not_authorized'))
    end
    account
  end

  def account_accessible_for_user?(account)
    @current_account_user = account.account_users.find_by(user_id: current_user.id)
    Current.account_user = @current_account_user
    render_unauthorized(I18n.t('errors.account.not_authorized')) unless @current_account_user
    assign_acting_user(account)
  end

  # PATCH LOCAL (fork): a integração do Portal age com a chave de um
  # administrador; com o cabeçalho X-Portal-Acting-Agent as atividades da
  # conversa (atribuiu, resolveu, prioridade, etiqueta) saem em nome do agente
  # que fez a ação no Portal. Só vale de administrador da conta e para agente
  # da mesma conta; resetado a cada requisição (a thread é reaproveitada).
  def assign_acting_user(account)
    Current.acting_user = nil
    agent_id = request.headers['X-Portal-Acting-Agent']
    return if agent_id.blank? || !@current_account_user&.administrator?

    Current.acting_user = account.users.find_by(id: agent_id)
  end

  def account_accessible_for_bot?(account)
    return if @resource.account_id == account.id
    return if @resource.agent_bot_inboxes.find_by(account_id: account.id)

    render_unauthorized('Bot is not authorized to access this account')
  end
end
