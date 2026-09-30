/* global axios */
// PATCH LOCAL (fork) - Assistente (IA com base na wiki). O backend do
// Chatwoot repassa pro Portal (PortalAssistantController).
import ApiClient from './ApiClient';

class PortalAssistantAPI extends ApiClient {
  constructor() {
    super('portal_assistant', { accountScoped: true });
  }

  ask(question) {
    return axios.post(`${this.url}/questions`, { question });
  }

  rate(questionId, rating) {
    return axios.patch(`${this.url}/questions/${questionId}`, { rating });
  }

  getQuestions({ filter, page }) {
    return axios.get(`${this.url}/questions`, { params: { filter, page } });
  }

  getAreas() {
    return axios.get(`${this.url}/areas`);
  }

  updateArea(areaId, included) {
    return axios.patch(`${this.url}/areas/${areaId}`, { included });
  }

  getAnswers(page) {
    return axios.get(`${this.url}/answers`, { params: { page } });
  }

  createAnswer(answer) {
    return axios.post(`${this.url}/answers`, answer);
  }

  updateAnswer(answerId, answer) {
    return axios.patch(`${this.url}/answers/${answerId}`, answer);
  }

  getSync() {
    return axios.get(`${this.url}/sync`);
  }

  startSync() {
    return axios.post(`${this.url}/sync`);
  }
}

export default new PortalAssistantAPI();
