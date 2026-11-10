# frozen_string_literal: true

require 'rails_helper'

# PATCH LOCAL (fork) - Grupos de clientes: todos veem, só administrador cria e altera.
RSpec.describe PortalGroupPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:record) { :portal_group }
  let(:administrator_context) { { user: administrator, account: account, account_user: account.account_users.find_by(user: administrator) } }
  let(:agent_context) { { user: agent, account: account, account_user: account.account_users.find_by(user: agent) } }

  permissions :index?, :show?, :options? do
    context 'when administrator' do
      it { expect(policy).to permit(administrator_context, record) }
    end

    context 'when agent' do
      it { expect(policy).to permit(agent_context, record) }
    end
  end

  permissions :create?, :update? do
    context 'when administrator' do
      it { expect(policy).to permit(administrator_context, record) }
    end

    context 'when agent' do
      it { expect(policy).not_to permit(agent_context, record) }
    end
  end
end
