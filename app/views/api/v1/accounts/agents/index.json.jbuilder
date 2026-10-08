# PATCH LOCAL (fork) - team_ids de cada agente (NewInternalTicket sugere o time pelo
# responsável), numa consulta só pra lista toda.
team_ids_by_agent = TeamMember.where(team_id: Current.account.teams.select(:id)).pluck(:user_id, :team_id)
                              .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }

json.array! @agents do |agent|
  json.partial! 'api/v1/models/agent', formats: [:json], resource: agent
  json.team_ids team_ids_by_agent.fetch(agent.id, [])
end
