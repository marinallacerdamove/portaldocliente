class Api::V1::Accounts::BulkActionsController < Api::V1::Accounts::BaseController
  include ResolveRequirementsGuard

  def create
    case normalized_type
    when 'Conversation'
      skipped_ids = unresolvable_conversation_ids
      enqueue_conversation_job(skipped_ids)
      render json: { skipped_ids: skipped_ids }
    when 'Contact'
      check_authorization_for_contact_action
      enqueue_contact_job
      head :ok
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end

  private

  def normalized_type
    params[:type].to_s.camelize
  end

  def enqueue_conversation_job(skipped_ids = [])
    job_params = conversation_params
    job_params[:ids] = Array(job_params[:ids]).map(&:to_s) - skipped_ids.map(&:to_s)
    return if job_params[:ids].empty?

    ::BulkActionsJob.perform_later(
      account: @current_account,
      user: current_user,
      params: job_params
    )
  end

  # PATCH LOCAL (fork) - ResolveRequirementsGuard: resolver em massa pula as
  # conversas que o botão Resolver travaria (a tela avisa quantas ficaram).
  def unresolvable_conversation_ids
    return [] unless params.dig(:fields, :status) == 'resolved'

    @current_account.conversations.where(display_id: params[:ids])
                    .reject { |conversation| resolve_requirements_missing(conversation).empty? }
                    .map(&:display_id)
  end

  def enqueue_contact_job
    Contacts::BulkActionJob.perform_later(
      @current_account.id,
      current_user.id,
      contact_params
    )
  end

  def delete_contact_action?
    params[:action_name] == 'delete'
  end

  def check_authorization_for_contact_action
    authorize(Contact, :destroy?) if delete_contact_action?
  end

  def conversation_params
    # TODO: Align conversation payloads with the `{ action_name, action_attributes }`
    # and then remove this method in favor of a common params method.
    base = params.permit(
      :snoozed_until,
      fields: [:status, :assignee_id, :team_id]
    )
    append_common_bulk_attributes(base)
  end

  def contact_params
    # TODO: remove this method in favor of a common params method.
    # once legacy conversation payloads are migrated.
    append_common_bulk_attributes({})
  end

  def append_common_bulk_attributes(base_params)
    # NOTE: Conversation payloads historically diverged per action. Going forward we
    # want all objects to share a common contract: `{ action_name, action_attributes }`
    common = params.permit(:type, :action_name, ids: [], labels: [add: [], remove: []])
    base_params.merge(common)
  end
end
