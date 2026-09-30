/* global axios */
import ApiClient from './ApiClient';

const buildParams = params =>
  new URLSearchParams(
    Object.entries(params).filter(
      ([key, value]) => value !== undefined && (value !== '' || key === 'q')
    )
  ).toString();

class CompanyAPI extends ApiClient {
  constructor() {
    super('companies', { accountScoped: true });
  }

  get(params = {}) {
    const { page = 1, sort = 'name' } = params;
    const requestURL = `${this.url}?${buildParams({ page, sort })}`;
    return axios.get(requestURL);
  }

  search(query = '', page = 1, sort = 'name') {
    const requestURL = `${this.url}/search?${buildParams({ q: query, page, sort })}`;
    return axios.get(requestURL);
  }

  listContacts(id, page = 1) {
    return axios.get(`${this.url}/${id}/contacts?${buildParams({ page })}`);
  }

  listNotes(id) {
    return axios.get(`${this.url}/${id}/notes`);
  }

  listConversations(id) {
    return axios.get(`${this.url}/${id}/conversations`);
  }

  searchContacts(id, query = '', page = 1) {
    const requestURL = `${this.url}/${id}/contacts/search?${buildParams({ q: query, page })}`;
    return axios.get(requestURL);
  }

  createContact(id, payload) {
    return axios.post(`${this.url}/${id}/contacts`, payload);
  }

  removeContact(id, contactId) {
    return axios.delete(`${this.url}/${id}/contacts/${contactId}`);
  }

  destroyCustomAttributes(id, customAttributes) {
    return axios.post(`${this.url}/${id}/destroy_custom_attributes`, {
      custom_attributes: customAttributes,
    });
  }

  destroyAvatar(id) {
    return axios.delete(`${this.url}/${id}/avatar`);
  }

  // PATCH LOCAL (fork) - aba Documentos (arquivos moram no Portal do Cliente)
  listDocuments(id) {
    return axios.get(`${this.url}/${id}/portal_documents`);
  }

  uploadDocument(id, categoria, file) {
    const formData = new FormData();
    formData.append('categoria', categoria);
    formData.append('file', file);
    return axios.post(`${this.url}/${id}/portal_documents`, formData);
  }

  updateDocument(id, fileId, observacao) {
    return axios.patch(`${this.url}/${id}/portal_documents/${fileId}`, {
      observacao,
    });
  }

  removeDocument(id, fileId) {
    return axios.delete(`${this.url}/${id}/portal_documents/${fileId}`);
  }

  downloadDocument(id, fileId) {
    return axios.get(`${this.url}/${id}/portal_documents/${fileId}/download`, {
      responseType: 'blob',
    });
  }
}

export default new CompanyAPI();
