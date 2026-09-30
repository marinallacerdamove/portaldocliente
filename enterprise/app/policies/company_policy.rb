class CompanyPolicy < ApplicationPolicy
  def index?
    true
  end

  def search?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def avatar?
    update?
  end

  def destroy_custom_attributes?
    update?
  end

  def destroy?
    @account_user.administrator?
  end

  # PATCH LOCAL (fork) - campos de Contrato/Financeiro da Empresa
  # (contrato_status, contrato_inicio, contrato_fim, contrato_valor,
  # modulos_contratados) só são visíveis/editáveis por quem tem essa
  # permissão. Sem o OR do administrator aqui, nem o admin da conta veria -
  # custom_role substitui ['administrator'] por completo, não soma (ver
  # Enterprise::AccountUser#permissions).
  def financeiro_manage?
    @account_user.administrator? || @account_user.permissions.include?('financeiro_manage')
  end
end
