# PATCH LOCAL (fork) - vincula a conversa a um ticket existente como pai ou
# filho (TicketLinkDialog.vue). relation é o papel do ticket_id em relação à
# conversa da rota. Ver Conversations::TicketLinkService.
class Api::V1::Accounts::Conversations::TicketLinksController < Api::V1::Accounts::Conversations::BaseController
  RELATIONS = %w[parent child].freeze

  def create
    return render json: { error: 'relation' }, status: :unprocessable_entity if RELATIONS.exclude?(params[:relation])

    related = Current.account.conversations.find_by!(display_id: params[:ticket_id])
    authorize related, :show?
    parent, child = params[:relation] == 'parent' ? [related, @conversation] : [@conversation, related]
    changed = Conversations::TicketLinkService.new(parent: parent, child: child).perform
    render json: { payload: changed.map { |conversation| { id: conversation.display_id, custom_attributes: conversation.custom_attributes } } }
  rescue Conversations::TicketLinkService::InvalidLink => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
