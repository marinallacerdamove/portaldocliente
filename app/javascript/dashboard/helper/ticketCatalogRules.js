// PATCH LOCAL (fork) - regras dos cadastros de atendimento (Serviços,
// Categorias, Status, Justificativas) usadas na conversa e no "Novo ticket
// interno". Formato dos registros: ver o topo de useTicketCatalog.js.
import { matchesTicketScope } from 'dashboard/composables/useTicketCatalog';

// Só o que está ativo e vale pro tipo de ticket da conversa, na ordem da API.
export const activeInScope = (items, scope) =>
  items.filter(item => item.active && matchesTicketScope(item, scope));

// Categorias que o serviço permite (all_categories = todas). Sem serviço
// escolhido, todas as ativas do tipo de ticket.
export const allowedCategories = (categories, service, scope) =>
  activeInScope(categories, scope).filter(
    category =>
      !service ||
      service.all_categories ||
      service.category_ids.includes(category.id)
  );

// allowed_priorities vazio = todas. "Nenhuma" (id null) fica sempre.
export const filterPriorityOptions = (options, category) => {
  const allowed = category?.allowed_priorities || [];
  if (!allowed.length) return options;
  return options.filter(
    option => option.id === null || allowed.includes(option.id)
  );
};

// Justificativas ativas do tipo de ticket ligadas ao status escolhido.
export const justificationsForStatus = (justifications, status, scope) =>
  status
    ? activeInScope(justifications, scope).filter(justification =>
        justification.status_ids.includes(status.id)
      )
    : [];
