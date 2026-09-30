# PATCH LOCAL (fork) - repasse das telas do Assistente pro Portal. Perguntar e
# avaliar: qualquer atendente. Treino (áreas, respostas próprias, histórico,
# sincronização): só administrador. Ver PortalAssistant::Client.
class Api::V1::Accounts::PortalAssistantController < Api::V1::Accounts::BaseController
  before_action :ensure_enabled
  before_action :check_admin_authorization?, except: [:ask, :rate]

  rescue_from PortalAssistant::Client::Error do |e|
    Rails.logger.error("[PortalAssistant] #{e.message}")
    render json: { error: I18n.t('portal_assistant.portal_unavailable') }, status: :bad_gateway
  end

  def ask
    forward(:post, 'questions', params.permit(:question))
  end

  def rate
    forward(:patch, "questions/#{params[:question_id].to_i}", params.permit(:rating))
  end

  def questions
    forward(:get, 'questions', params.permit(:filter, :page))
  end

  def areas
    forward(:get, 'areas')
  end

  def update_area
    forward(:patch, "areas/#{params[:area_id].to_i}", params.permit(:included))
  end

  def answers
    forward(:get, 'answers', params.permit(:page))
  end

  def create_answer
    forward(:post, 'answers', params.permit(:title, :content, :active))
  end

  def update_answer
    forward(:patch, "answers/#{params[:answer_id].to_i}", params.permit(:title, :content, :active))
  end

  def sync
    forward(:get, 'sync')
  end

  def start_sync
    forward(:post, 'sync')
  end

  private

  def ensure_enabled
    head :not_found unless PortalAssistant::Client.enabled_for?(Current.account)
  end

  def forward(method, path, permitted = {})
    status, body = PortalAssistant::Client.new(account: Current.account, user: Current.user).request(method, path, permitted.to_h)
    body.present? ? render(json: body, status: status) : head(status)
  end
end
