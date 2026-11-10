// PATCH LOCAL (fork) - Grupos de clientes (só leitura, cadastro no Portal).
import { frontendURL } from '../../../helper/URLHelper';
import PortalGroupsIndex from './pages/PortalGroupsIndex.vue';
import PortalGroupDetail from './pages/PortalGroupDetail.vue';

const commonMeta = { permissions: ['administrator', 'agent'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/groups'),
    name: 'portal_groups_index',
    component: PortalGroupsIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/groups/:groupId'),
    name: 'portal_groups_show',
    component: PortalGroupDetail,
    meta: commonMeta,
  },
];
