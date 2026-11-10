// PATCH LOCAL (fork) - Grupos de clientes (só leitura). O cadastro mora no
// Portal; o backend do Chatwoot repassa (PortalGroupsController). get() lista
// e show(id) traz o detalhe ("todos" é o grupo automático).
import ApiClient from './ApiClient';

class PortalGroupsAPI extends ApiClient {
  constructor() {
    super('portal_groups', { accountScoped: true });
  }
}

export default new PortalGroupsAPI();
