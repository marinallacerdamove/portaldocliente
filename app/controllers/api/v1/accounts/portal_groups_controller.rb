# PATCH LOCAL (fork) - tela Grupos (só leitura): repassa os grupos de clientes
# do Portal do Cliente (ver PortalGroups::Client). Qualquer usuário da conta
# vê; o cadastro e a edição são feitos no Portal.
class Api::V1::Accounts::PortalGroupsController < Api::V1::Accounts::BaseController
  rescue_from PortalGroups::Client::Error do |e|
    Rails.logger.error("[PortalGroups] #{e.message}")
    if e.status == 404
      render json: { error: I18n.t('portal_groups.not_found') }, status: :not_found
    else
      render json: { error: I18n.t('portal_groups.portal_unavailable') }, status: :bad_gateway
    end
  end

  def index
    render json: { data: client.list }
  end

  def show
    render json: client.show(params[:id])
  end

  private

  def client
    PortalGroups::Client.new(account: Current.account)
  end
end
