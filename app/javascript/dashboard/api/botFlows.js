import ApiClient from './ApiClient';

class BotFlowsAPI extends ApiClient {
  constructor() {
    super('bot_flows', { accountScoped: true });
  }
}

export default new BotFlowsAPI();
