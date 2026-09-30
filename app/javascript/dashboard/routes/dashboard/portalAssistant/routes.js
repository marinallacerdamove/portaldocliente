// PATCH LOCAL (fork) - Assistente (IA com base na wiki).
import { frontendURL } from '../../../helper/URLHelper';
import PortalAssistantIndex from './pages/PortalAssistantIndex.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/assistant'),
    name: 'portal_assistant_index',
    component: PortalAssistantIndex,
    meta: { permissions: ['administrator', 'agent'] },
  },
];
