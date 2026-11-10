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

  # quem recebe (o grupo automático só tem essa lista pra mostrar)
  def recipients?
    true
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end
end
