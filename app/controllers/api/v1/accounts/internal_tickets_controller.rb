# PATCH LOCAL (fork) - cria um ticket completo numa chamada só ("Novo ticket
# interno" e ticket pai/filho novo). O corpo vem em params[:ticket] como JSON
# (custom_attributes tem hash aninhado) e os anexos em params[:attachments],
# por isso multipart. Ver Conversations::InternalTicketService.
class Api::V1::Accounts::InternalTicketsController < Api::V1::Accounts::BaseController
  def create
    inbox = Current.account.inboxes.find(ticket_params[:inbox_id])
    authorize inbox, :show?
    @conversation = Conversations::InternalTicketService.new(
      inbox: inbox, contact: Current.account.contacts.find(ticket_params[:contact_id]), user: Current.user, params: service_params
    ).perform
    render 'api/v1/accounts/conversations/create'
  rescue Conversations::InternalTicketService::InvalidTicket, Conversations::TicketLinkService::InvalidLink, JSON::ParserError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def ticket_params
    @ticket_params ||= ActionController::Parameters.new(JSON.parse(params.require(:ticket))).permit(
      :inbox_id, :contact_id, :team_id, :assignee_id, :priority,
      custom_attributes: {}, message: [:content, :private], copy: [:source_conversation_id, { message_ids: [] }],
      watcher_ids: [], link: [:conversation_id, :relation, :announce]
    )
  end

  def service_params
    {
      team: ticket_params[:team_id].presence && Current.account.teams.find(ticket_params[:team_id]),
      assignee: ticket_params[:assignee_id].presence && Current.account.users.find(ticket_params[:assignee_id]),
      priority: ticket_params[:priority], custom_attributes: ticket_params[:custom_attributes],
      message: message_params, copy: copy_params, watcher_ids: ticket_params[:watcher_ids], link: link_params
    }
  end

  def message_params
    message = ticket_params[:message].to_h
    message.merge(attachments: params[:attachments]).with_indifferent_access
  end

  def copy_params
    copy = ticket_params[:copy]
    return if copy.blank?

    { source: visible_conversation(copy[:source_conversation_id]), message_ids: copy[:message_ids] }
  end

  def link_params
    link = ticket_params[:link]
    return if link.blank?

    { conversation: visible_conversation(link[:conversation_id]), relation: link[:relation],
      announce: ActiveModel::Type::Boolean.new.cast(link[:announce]) }
  end

  def visible_conversation(display_id)
    conversation = Current.account.conversations.find_by!(display_id: display_id)
    authorize conversation, :show?
    conversation
  end
end
