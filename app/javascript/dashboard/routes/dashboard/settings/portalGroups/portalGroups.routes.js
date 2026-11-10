// PATCH LOCAL (fork) - Grupos de clientes em Configurações, no mesmo formato
// dos cadastros de atendimento: lista no SettingsWrapper, ficha no
// SettingsContent com botão de voltar. Os dados moram no Portal. Agente vê em
// modo leitura; só administrador cria e altera (o backend também barra). Sem
// cache de página: a lista e a ficha sempre recarregam do Portal.
import { frontendURL } from 'dashboard/helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';
import SettingsContent from '../Wrapper.vue';
import SettingsWrapper from '../SettingsWrapper.vue';
import PortalGroupsIndex from './Index.vue';
import PortalGroupDetail from './Detail.vue';

const meta = { permissions: [...ROLES, ...CONVERSATION_PERMISSIONS] };
const basePath = frontendURL('accounts/:accountId/settings/groups');

export default {
  routes: [
    {
      path: basePath,
      component: SettingsWrapper,
      props: { keepAlive: false },
      children: [
        {
          path: '',
          name: 'portal_groups_list',
          component: PortalGroupsIndex,
          meta,
        },
      ],
    },
    {
      path: basePath,
      component: SettingsContent,
      props: {
        headerTitle: 'PORTAL_GROUPS.TITLE',
        showBackButton: true,
        backUrl: { name: 'portal_groups_list' },
        keepAlive: false,
      },
      children: [
        {
          path: ':groupId',
          name: 'portal_groups_show',
          component: PortalGroupDetail,
          meta,
        },
      ],
    },
  ],
};
