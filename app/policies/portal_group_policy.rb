# PATCH LOCAL (fork) - Grupos de clientes (dados no Portal): todo usuário da
# conta vê (a tela e o público das campanhas usam a lista), só administrador
# cria e altera.
class PortalGroupPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def options?
    true
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end
end
