class MacroPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    true
  end

  # PATCH LOCAL (fork) - macro de equipe: membros das equipes veem e usam,
  # só administrador altera (igual à global).
  def show?
    @account_user.administrator? || @record.available_to?(@account_user.user)
  end

  def update?
    return @account_user.administrator? if @record.global? || @record.team?

    author?
  end

  def destroy?
    return @account_user.administrator? if @record.global? || @record.team?

    author?
  end

  def execute?
    @record.available_to?(@account_user.user)
  end

  private

  def author?
    @record.created_by == @account_user.user
  end
end
