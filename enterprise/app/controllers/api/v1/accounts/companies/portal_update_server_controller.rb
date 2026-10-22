# PATCH LOCAL (fork) - aba Update Server da empresa (bases + licenças),
# repassada pro Portal do Cliente (ver PortalUpdateServer::Client). Ver: quem
# vê a empresa; gravar: quem edita a empresa. Sem exclusão: base e licença
# saem de uso inativando (campo active).
class Api::V1::Accounts::Companies::PortalUpdateServerController < Api::V1::Accounts::Companies::BaseController
  BASE_PARAMS = %i[albatross_id display_code razao_social display_name database_name link documento active].freeze
  LICENSE_PARAMS = [:code, :license_type, :user_name, :active, { license_module_ids: [] }].freeze

  before_action :authorize_company_read!, only: [:show]
  before_action :authorize_company_update!, only: [:create_base, :update_base, :create_license, :update_license]

  rescue_from PortalDocuments::Client::Error do |e|
    Rails.logger.error("[PortalUpdateServer] #{e.message}")
    render json: { error: I18n.t('portal_update_server.portal_unavailable') }, status: :bad_gateway
  end

  def show
    relay(client.show)
  end

  def create_base
    relay(client.save_base(nil, base_params.to_h))
  end

  def update_base
    relay(client.save_base(params[:id], base_params.to_h))
  end

  def create_license
    relay(client.save_license(nil, license_params.to_h))
  end

  def update_license
    relay(client.save_license(params[:id], license_params.to_h))
  end

  private

  def client
    PortalUpdateServer::Client.new(account: Current.account, company: @company)
  end

  def base_params
    params.require(:base).permit(*BASE_PARAMS)
  end

  def license_params
    params.require(:license).permit(*LICENSE_PARAMS)
  end

  def relay(portal_response)
    portal_response.body.present? ? render(json: portal_response.body, status: portal_response.code) : head(portal_response.code)
  end
end
