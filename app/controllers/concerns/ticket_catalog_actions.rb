# PATCH LOCAL (fork) - CRUD dos cadastros de atendimento (serviços, categorias,
# status, justificativas). Sem destroy: registro sai de uso sendo inativado.
module TicketCatalogActions
  extend ActiveSupport::Concern

  included do
    before_action :fetch_record, only: [:show, :update]
    before_action :check_authorization
  end

  def index
    render json: { payload: catalog_scope.ordered }
  end

  def show
    render json: @record
  end

  def create
    @record = catalog_scope.new
    save_record
  end

  def update
    save_record
  end

  private

  def save_record
    ActiveRecord::Base.transaction do
      @record.assign_attributes(record_params)
      assign_associations
      @record.save!
    end
    render json: @record.reload
  end

  # Associações N:N (categorias do serviço, status da justificativa).
  def assign_associations; end

  def catalog_scope
    Current.account.public_send(self.class::CATALOG_MODEL.model_name.plural)
  end

  def fetch_record
    @record = catalog_scope.find(params[:id])
  end

  def check_authorization
    authorize(@record || self.class::CATALOG_MODEL)
  end
end
