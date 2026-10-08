// PATCH LOCAL (fork) - mensagem pra quando a troca de status falha. O servidor
// recusa resolver sem o que o Resolver cobra (422 com `missing`, ver
// ResolveRequirementsGuard) e a tela diz o que falta.
export const statusChangeErrorMessage = (error, t) => {
  const missing = error?.response?.data?.missing;
  return missing?.length
    ? t('CONVERSATION.RESOLVE_BLOCKED', { fields: missing.join(', ') })
    : t('CONVERSATION.CHANGE_STATUS_FAILED');
};
