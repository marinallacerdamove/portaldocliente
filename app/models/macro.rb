# == Schema Information
#
# Table name: macros
#
#  id            :bigint           not null, primary key
#  actions       :jsonb            not null
#  group_name    :string
#  name          :string           not null
#  team_ids      :bigint           default([]), not null, is an Array
#  user_ids      :bigint           default([]), not null, is an Array
#  visibility    :integer          default("personal")
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  created_by_id :bigint
#  updated_by_id :bigint
#
# Indexes
#
#  index_macros_on_account_id  (account_id)
#
class Macro < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :account
  belongs_to :created_by,
             class_name: :User, optional: true, inverse_of: :macros
  belongs_to :updated_by,
             class_name: :User, optional: true
  has_many_attached :files

  # PATCH LOCAL (fork) - team: só membros das equipes em team_ids e os agentes
  # em user_ids veem e usam.
  enum visibility: { personal: 0, global: 1, team: 2 }

  validate :json_actions_format
  validate :teams_for_team_visibility

  before_validation :normalize_group_and_teams

  # PATCH LOCAL (fork) - fill_reply (preenche o editor, roda no navegador),
  # set_subject, replace_labels, remove_all_labels e set_custom_attribute.
  ACTIONS_ATTRS = %w[send_message add_label assign_team assign_agent mute_conversation change_status remove_label remove_assigned_agent
                     remove_assigned_team resolve_conversation snooze_conversation change_priority send_email_transcript
                     send_attachment add_private_note send_webhook_event
                     fill_reply set_subject replace_labels remove_all_labels set_custom_attribute].freeze

  def set_visibility(user, params)
    self.visibility = params[:visibility]
    self.visibility = :personal if user.agent?
  end

  # Administrador vê todas as macros de equipe (pra gerenciar); atendente só
  # as das equipes dele.
  def self.with_visibility(user, _params)
    macros = Current.account.macros
    records = macros.global.or(macros.personal.where(created_by_id: user.id))
    team_macros = macros.team
    unless Current.account_user&.administrator?
      team_macros = team_macros.where('macros.team_ids && ARRAY[?]::bigint[] OR ? = ANY(macros.user_ids)',
                                      user.team_ids.presence || [0], user.id)
    end
    records.or(team_macros).order(:id)
  end

  def self.current_page(params)
    params[:page] || 1
  end

  def file_base_data
    files.map do |file|
      {
        id: file.id,
        macro_id: id,
        file_type: file.content_type,
        account_id: account_id,
        file_url: url_for(file),
        blob_id: file.blob_id,
        filename: file.filename.to_s
      }
    end
  end

  def available_to?(user)
    return true if global? || created_by_id == user.id

    team? && (user.team_ids.intersect?(team_ids) || user_ids.include?(user.id))
  end

  private

  def normalize_group_and_teams
    self.group_name = group_name.to_s.squish.presence
    self.team_ids = team? ? Array(team_ids).compact_blank.map(&:to_i).uniq : []
    self.user_ids = team? ? Array(user_ids).compact_blank.map(&:to_i).uniq : []
  end

  def teams_for_team_visibility # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    return unless team?

    errors.add(:team_ids, :blank) if team_ids.empty? && user_ids.empty?
    errors.add(:team_ids, :invalid) if account && account.teams.where(id: team_ids).count != team_ids.size
    errors.add(:user_ids, :invalid) if account && account.users.where(id: user_ids).count != user_ids.size
  end

  def json_actions_format
    return if actions.blank?

    attributes = actions.map { |obj, _| obj['action_name'] }
    actions = attributes - ACTIONS_ATTRS

    errors.add(:actions, "Macro execution actions #{actions.join(',')} not supported.") if actions.any?
  end
end

Macro.include_mod_with('Audit::Macro')
