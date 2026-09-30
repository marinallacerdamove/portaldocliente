# PATCH LOCAL (fork) - aba Documentos da empresa, repassada pro Portal do
# Cliente (ver PortalDocuments::Client). Ver: quem vê a empresa; mexer: quem
# edita a empresa.
class Api::V1::Accounts::Companies::PortalDocumentsController < Api::V1::Accounts::Companies::BaseController
  before_action :authorize_company_read!, only: [:index, :download]
  before_action :authorize_company_update!, only: [:create, :update, :destroy]

  rescue_from PortalDocuments::Client::Error do |e|
    Rails.logger.error("[PortalDocuments] #{e.message}")
    render json: { error: I18n.t('portal_documents.portal_unavailable') }, status: :bad_gateway
  end

  def index
    relay(client.list)
  end

  def create
    relay(client.upload(params.require(:file), params[:categoria]))
  end

  def update
    relay(client.update(params[:id], params[:observacao]))
  end

  def destroy
    relay(client.destroy(params[:id]))
  end

  def download
    portal_response = client.download(params[:id])
    return relay(portal_response) unless portal_response.success?

    response.headers['Content-Disposition'] = portal_response.headers['content-disposition']
    render body: portal_response.body, content_type: portal_response.headers['content-type']
  end

  private

  def client
    PortalDocuments::Client.new(account: Current.account, company: @company)
  end

  def relay(portal_response)
    portal_response.body.present? ? render(json: portal_response.body, status: portal_response.code) : head(portal_response.code)
  end
end
