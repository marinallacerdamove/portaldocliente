import { shallowMount, flushPromises } from '@vue/test-utils';
import CompanyPortalProfileCard from '../CompanyPortalProfileCard.vue';
import CompanyAPI from 'dashboard/api/companies';
import { useAlert } from 'dashboard/composables';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key, locale: { value: 'pt_BR' } }),
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: 1 } }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({ shouldShow: () => true }),
}));
vi.mock('dashboard/stores/companies', () => ({
  useCompaniesStore: () => ({ getUIFlags: {}, update: vi.fn() }),
}));
vi.mock('dashboard/api/companies', () => ({ default: { get: vi.fn() } }));

const mountCard = async () => {
  const wrapper = shallowMount(CompanyPortalProfileCard, {
    props: { company: { id: 1, name: 'Matriz', customAttributes: {} } },
  });
  await flushPromises();
  return wrapper;
};

describe('CompanyPortalProfileCard account companies', () => {
  it('loads every page of the account companies', async () => {
    CompanyAPI.get.mockImplementation(async ({ page }) => ({
      data: {
        payload: [
          { id: page * 10 + 1, name: `Empresa ${page}a` },
          { id: page * 10 + 2, name: `Empresa ${page}b` },
        ],
        meta: { total_count: 5 },
      },
    }));

    const wrapper = await mountCard();

    expect(CompanyAPI.get.mock.calls.map(([params]) => params.page)).toEqual([
      1, 2, 3,
    ]);
    expect(wrapper.vm.accountCompanies).toHaveLength(6);
  });

  // Regressão B236: a tela de empresas não avisava quando a lista de empresas
  // da conta falhava ao carregar (erro engolido).
  it('warns the user when the account companies fail to load', async () => {
    CompanyAPI.get.mockRejectedValue(new Error('500'));

    await mountCard();

    expect(useAlert).toHaveBeenCalledWith(
      'COMPANIES.DETAIL.PROFILE.MESSAGES.LOAD_COMPANIES_ERROR'
    );
  });
});

describe('CompanyPortalProfileCard tabs', () => {
  it('keeps the same tab order as the Portal, with Update Server before Documentos', async () => {
    const wrapper = await mountCard();

    expect(wrapper.vm.CARD_TABS.map(tab => tab.key)).toEqual([
      'dados',
      'financeiro',
      'contabilidade',
      'update_server',
      'documentos',
    ]);
  });
});
