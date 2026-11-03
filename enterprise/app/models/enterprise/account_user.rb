module Enterprise::AccountUser
  # PATCH LOCAL (fork) - contracts_access vale também pra quem tem perfil
  # personalizado (o perfil substitui a lista do super).
  def permissions
    return super if custom_role.blank?

    custom_role.permissions + ['custom_role'] + (contracts_access? ? [AccountUser::CONTRACTS_PERMISSION] : [])
  end
end
