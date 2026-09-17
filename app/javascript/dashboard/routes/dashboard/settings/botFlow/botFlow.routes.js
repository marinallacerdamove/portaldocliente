import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import SettingsContent from '../Wrapper.vue';
import BotFlowsIndex from './Index.vue';
import BotFlowEditor from './Editor/Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/bot-flows'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => ({ name: 'bot_flows_list', params: to.params }),
        },
        {
          path: 'list',
          name: 'bot_flows_list',
          component: BotFlowsIndex,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/settings/bot-flows'),
      component: SettingsContent,
      props: () => ({
        headerTitle: 'BOT_FLOW.EDITOR.HEADER',
        icon: 'i-lucide-workflow',
        showBackButton: true,
        backUrl: { name: 'bot_flows_list' },
      }),
      children: [
        {
          path: 'new',
          name: 'bot_flows_new',
          component: BotFlowEditor,
          meta: { permissions: ['administrator'] },
        },
        {
          path: ':botFlowId/edit',
          name: 'bot_flows_edit',
          component: BotFlowEditor,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
