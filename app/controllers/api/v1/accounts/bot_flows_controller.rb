class Api::V1::Accounts::BotFlowsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_bot_flow, only: [:show, :update, :destroy]

  def index
    @bot_flows = Current.account.bot_flows.order(:priority, :id)
  end

  def show; end

  def create
    @bot_flow = Current.account.bot_flows.new(bot_flow_permit)
    @bot_flow.nodes = params[:nodes] if params[:nodes]
    @bot_flow.edges = params[:edges] if params[:edges]
    @bot_flow.save!
  end

  def update
    @bot_flow.assign_attributes(bot_flow_permit)
    @bot_flow.nodes = params[:nodes] if params[:nodes]
    @bot_flow.edges = params[:edges] if params[:edges]
    @bot_flow.save!
  end

  def destroy
    @bot_flow.destroy!
    head :ok
  end

  private

  def bot_flow_permit
    params.permit(:name, :description, :active, :trigger_type, :priority, inbox_ids: [], trigger_config: {})
  end

  def fetch_bot_flow
    @bot_flow = Current.account.bot_flows.find_by(id: params[:id])
  end
end
