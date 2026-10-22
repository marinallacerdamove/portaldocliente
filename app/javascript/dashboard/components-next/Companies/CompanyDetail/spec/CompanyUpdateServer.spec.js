import { shallowMount, flushPromises } from '@vue/test-utils';
import CompanyUpdateServer from '../CompanyUpdateServer.vue';
import CompanyUpdateServerBases from '../CompanyUpdateServerBases.vue';
import CompanyUpdateServerLicenses from '../CompanyUpdateServerLicenses.vue';
import CompanyAPI from 'dashboard/api/companies';
import { useAlert } from 'dashboard/composables';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/companies', () => ({
  default: {
    getUpdateServer: vi.fn(),
    saveUpdateServerBase: vi.fn(),
    saveUpdateServerLicense: vi.fn(),
  },
}));

const payload = (overrides = {}) => ({
  bases: [{ id: 1, albatross_id: 156, active: true }],
  licenses: [],
  modules: [{ id: 1, code: 'STK', name: 'Estoque', active: true }],
  summary: { license_count: 0, per_module: [], combinations: [] },
  ...overrides,
});

const mountTab = async () => {
  const wrapper = shallowMount(CompanyUpdateServer, {
    props: { companyId: 7 },
  });
  await flushPromises();
  return wrapper;
};

describe('CompanyUpdateServer', () => {
  beforeEach(() => vi.clearAllMocks());

  it('loads the Portal data and hands it to the sections', async () => {
    CompanyAPI.getUpdateServer.mockResolvedValue({ data: payload() });

    const wrapper = await mountTab();

    expect(CompanyAPI.getUpdateServer).toHaveBeenCalledWith(7);
    expect(
      wrapper.findComponent(CompanyUpdateServerBases).props('bases')
    ).toEqual([{ id: 1, albatross_id: 156, active: true }]);
    expect(
      wrapper.findComponent(CompanyUpdateServerLicenses).props('modules')
    ).toHaveLength(1);
  });

  it('shows the not linked message when the Portal answers 404', async () => {
    CompanyAPI.getUpdateServer.mockRejectedValue({ response: { status: 404 } });

    const wrapper = await mountTab();

    expect(wrapper.vm.isNotLinked).toBe(true);
    expect(wrapper.findComponent(CompanyUpdateServerBases).exists()).toBe(
      false
    );
  });

  it('shows the load error for any other failure', async () => {
    CompanyAPI.getUpdateServer.mockRejectedValue({ response: { status: 502 } });

    const wrapper = await mountTab();

    expect(wrapper.vm.loadFailed).toBe(true);
  });

  it('replaces the data with the Portal answer after saving a base', async () => {
    CompanyAPI.getUpdateServer.mockResolvedValue({ data: payload() });
    const saved = payload({ bases: [{ id: 2, albatross_id: 157 }] });
    CompanyAPI.saveUpdateServerBase.mockResolvedValue({ data: saved });

    const wrapper = await mountTab();
    const ok = await wrapper.vm.saveBase(null, { albatross_id: 157 });

    expect(ok).toBe(true);
    expect(CompanyAPI.saveUpdateServerBase).toHaveBeenCalledWith(7, null, {
      albatross_id: 157,
    });
    expect(wrapper.vm.data.bases).toEqual([{ id: 2, albatross_id: 157 }]);
  });

  it('alerts with the Portal validation messages and keeps the form open', async () => {
    CompanyAPI.getUpdateServer.mockResolvedValue({ data: payload() });
    CompanyAPI.saveUpdateServerLicense.mockRejectedValue({
      response: { data: { errors: ['Escolha ao menos um módulo'] } },
    });

    const wrapper = await mountTab();
    const ok = await wrapper.vm.saveLicense(null, { user_name: 'ana' });

    expect(ok).toBe(false);
    expect(useAlert).toHaveBeenCalledWith('Escolha ao menos um módulo');
    expect(wrapper.vm.data.bases).toHaveLength(1);
  });

  it('uses the generic message when the save fails without details', async () => {
    CompanyAPI.getUpdateServer.mockResolvedValue({ data: payload() });
    CompanyAPI.saveUpdateServerBase.mockRejectedValue({
      response: { status: 502 },
    });

    const wrapper = await mountTab();
    await wrapper.vm.saveBase(1, { active: false });

    expect(useAlert).toHaveBeenCalledWith(
      'COMPANIES.DETAIL.UPDATE_SERVER.SAVE_ERROR'
    );
  });
});
