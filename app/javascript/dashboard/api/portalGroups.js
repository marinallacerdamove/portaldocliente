/* global axios */
// PATCH LOCAL (fork) - Grupos de clientes. Os dados moram no Portal; o backend
// do Chatwoot repassa (PortalGroupsController). "todos" é o grupo automático
// (não edita). Só administrador cria e altera.
import ApiClient from './ApiClient';

class PortalGroupsAPI extends ApiClient {
  constructor() {
    super('portal_groups', { accountScoped: true });
  }

  // Sem all: só os grupos ativos (público de campanha). Com all: inclui os inativos.
  get({ all = false } = {}) {
    return axios.get(this.url, { params: all ? { all: 1 } : {} });
  }

  // Empresas e contatos avulsos que podem entrar num grupo. Não pode se chamar
  // options(): o ApiClient guarda as opções do cliente nessa propriedade.
  memberOptions() {
    return axios.get(`${this.url}/options`);
  }

  create(attributes) {
    return axios.post(this.url, { client_group: attributes });
  }

  // As listas (empresa_ids, partner_ids) são sempre a lista COMPLETA; ausente = não mexe.
  update(id, attributes) {
    return axios.patch(`${this.url}/${id}`, { client_group: attributes });
  }
}

export default new PortalGroupsAPI();
