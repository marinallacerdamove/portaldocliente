# PATCH LOCAL (fork) - cadastros de atendimento: todo agente lê (a conversa usa
# as listas), só administrador cadastra e altera.
class TicketCatalogPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end
end
