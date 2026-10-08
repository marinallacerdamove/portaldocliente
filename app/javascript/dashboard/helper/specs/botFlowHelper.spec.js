import { BOT_FLOW_CHATWOOT_ACTIONS } from '../botFlowHelper';
import serverActions from '../../../../../spec/fixtures/fork_parity/bot_flow_chatwoot_actions.json';

describe('BOT_FLOW_CHATWOOT_ACTIONS', () => {
  it('matches the actions the server accepts (BotFlow::CHATWOOT_ACTIONS)', () => {
    expect([...BOT_FLOW_CHATWOOT_ACTIONS]).toEqual(serverActions);
  });
});
