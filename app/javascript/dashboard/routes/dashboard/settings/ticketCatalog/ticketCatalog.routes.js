// PATCH LOCAL (fork) - rotas dos cadastros de atendimento (Serviços,
// Categorias, Status, Justificativas), no mesmo formato das Macros: lista no
// SettingsWrapper, ficha no SettingsContent com botão de voltar. Sem rota de
// excluir: registro sai de uso sendo inativado.
import { frontendURL } from 'dashboard/helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';
import SettingsContent from '../Wrapper.vue';
import SettingsWrapper from '../SettingsWrapper.vue';
import CatalogIndex from './CatalogIndex.vue';
import CatalogEditor from './CatalogEditor.vue';
import { CATALOG_KINDS, catalogRouteName } from './constants';

const meta = { permissions: [...ROLES, ...CONVERSATION_PERMISSIONS] };

const kindRoutes = ([kind, { i18nKey, path, icon }]) => {
  const basePath = frontendURL(`accounts/:accountId/settings/${path}`);
  return [
    {
      path: basePath,
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: catalogRouteName(kind, 'list'),
          component: CatalogIndex,
          props: { kind },
          meta,
        },
      ],
    },
    {
      path: basePath,
      component: SettingsContent,
      props: () => ({
        headerTitle: `TICKET_CATALOG.${i18nKey}.HEADER`,
        icon,
        showBackButton: true,
      }),
      children: [
        {
          path: 'new',
          name: catalogRouteName(kind, 'new'),
          component: CatalogEditor,
          props: { kind },
          meta,
        },
        {
          path: ':recordId/edit',
          name: catalogRouteName(kind, 'edit'),
          component: CatalogEditor,
          props: { kind },
          meta,
        },
      ],
    },
  ];
};

export default {
  routes: Object.entries(CATALOG_KINDS).flatMap(kindRoutes),
};
