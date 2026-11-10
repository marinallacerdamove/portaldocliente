# PATCH LOCAL (fork) - tela Grupos (Configurações): repassa o cadastro de
# grupos de clientes guardado no Portal do Cliente (ver PortalGroups::Client).
# Qualquer usuário da conta vê; só administrador cria e altera (PortalGroupPolicy).
class Api::V1::Accounts::PortalGroupsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  rescue_from PortalGroups::Client::Error do |e|
    Rails.logger.error("[PortalGroups] #{e.message}")
    case e.status
    when 404 then render json: { error: I18n.t('portal_groups.not_found') }, status: :not_found
    when 422 then render json: { errors: e.errors.presence || [I18n.t('portal_groups.invalid')] }, status: :unprocessable_entity
    else render json: { error: I18n.t('portal_groups.portal_unavailable') }, status: :bad_gateway
    end
  end

  def index
    render json: { data: client.list(all: ActiveModel::Type::Boolean.new.cast(params[:all])) }
  end

  def show
    render json: client.show(params[:id])
  end

  def options
    render json: client.options
  end

  def create
    render json: client.create(group_params.to_h), status: :created
  end

  def update
    render json: client.update(params[:id], group_params.to_h)
  end

  private

  def check_authorization
    authorize(:portal_group)
  end

  def group_params
    params.require(:client_group).permit(:name, :active, empresa_ids: [], partner_ids: [])
  end

  def client
    PortalGroups::Client.new(account: Current.account, user: Current.user)
  end
end
