module AssignmentHandler
  extend ActiveSupport::Concern
  include Events::Types

  included do
    before_save :ensure_team_from_assignee, :ensure_assignee_is_from_team
    after_commit :notify_assignment_change, :process_assignment_changes
  end

  private

  # Fork: ao atribuir um agente, a conversa vai junto pro time dele. Só
  # quando dá pra saber qual time é: se o agente já é do time atual, nada
  # muda; se está em mais de um time da conta, não chuta (a escolha fica
  # com quem atende). Troca de time explícita no mesmo save tem prioridade.
  def ensure_team_from_assignee # rubocop:disable Metrics/CyclomaticComplexity
    return unless assignee_id_changed? && assignee_id.present?
    return if team_id_changed?
    return if team&.members&.include?(assignee)

    agent_teams = account.teams.joins(:team_members).where(team_members: { user_id: assignee_id }).to_a
    self.team = agent_teams.first if agent_teams.one?
  end

  def ensure_assignee_is_from_team
    return unless team_id_changed?
    return if assignee_agent_bot_id.present?

    validate_current_assignee_team
    self.assignee ||= find_assignee_from_team
  end

  def validate_current_assignee_team
    self.assignee_id = nil if team&.members&.exclude?(assignee)
  end

  def find_assignee_from_team
    return if team&.allow_auto_assign.blank?

    team_members_with_capacity = inbox.member_ids_with_assignment_capacity & team.members.ids
    ::AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: team_members_with_capacity).find_assignee
  end

  def notify_assignment_change
    {
      ASSIGNEE_CHANGED => -> { saved_change_to_assignee_id? || saved_change_to_assignee_agent_bot_id? },
      TEAM_CHANGED => -> { saved_change_to_team_id? }
    }.each do |event, condition|
      condition.call && dispatcher_dispatch(event, previous_changes)
    end
  end

  def process_assignment_changes
    process_assignment_activities
  end

  def process_assignment_activities
    user_name = Current.user.name if Current.user.present?
    if saved_change_to_team_id?
      create_team_change_activity(user_name)
    elsif saved_change_to_assignee_id?
      create_assignee_change_activity(user_name)
    end
  end

  def self_assign?(assignee_id)
    assignee_id.present? && Current.user&.id == assignee_id
  end
end
