// PATCH LOCAL (fork) - Grupos de clientes em Configurações, numa tela só (lista
// que abre os contatos de cada grupo). Os dados moram no Portal. Agente vê em
// modo leitura; só administrador cria e altera (o backend também barra). Sem
// cache de página: a lista sempre recarrega do Portal.
import { frontendURL } from 'dashboard/helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';
import SettingsWrapper from '../SettingsWrapper.vue';
import PortalGroupsIndex from './Index.vue';

const meta = { permissions: [...ROLES, ...CONVERSATION_PERMISSIONS] };

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/groups'),
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
  ],
};
