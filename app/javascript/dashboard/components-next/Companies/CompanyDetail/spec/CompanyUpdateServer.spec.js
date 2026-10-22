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
    saveUpdateServerModule: vi.fn(),
    reorderUpdateServerModules: vi.fn(),
  },
}));

const payload = (overrides = {}) => ({
  bases: [{ id: 1, albatross_id: 9001, active: true }],
  licenses: [],
  modules: [{ id: 1, code: 'STK', name: 'Estoque', active: true }],
  summary: { license_count: 0, per_module: [], combinations: [] },
  ...overrides,
});

// Cada aba montada escuta o foco da janela: desmonta todas ao fim de cada teste
// pra um teste não disparar a recarga do outro.
const mounted = [];

const mountTab = async () => {
  const wrapper = shallowMount(CompanyUpdateServer, {
    props: { companyId: 7 },
  });
  mounted.push(wrapper);
  await flushPromises();
  return wrapper;
};

describe('CompanyUpdateServer', () => {
  beforeEach(() => vi.clearAllMocks());
  afterEach(() => mounted.splice(0).forEach(wrapper => wrapper.unmount()));

  it('loads the Portal data and hands it to the sections', async () => {
    CompanyAPI.getUpdateServer.mockResolvedValue({ data: payload() });

    const wrapper = await mountTab();

    expect(CompanyAPI.getUpdateServer).toHaveBeenCalledWith(7);
    expect(
      wrapper.findComponent(CompanyUpdateServerBases).props('bases')
    ).toEqual([{ id: 1, albatross_id: 9001, active: true }]);
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
    const saved = payload({ bases: [{ id: 2, albatross_id: 9002 }] });
    CompanyAPI.saveUpdateServerBase.mockResolvedValue({ data: saved });

    const wrapper = await mountTab();
    const ok = await wrapper.vm.saveBase(null, { albatross_id: 9002 });

    expect(ok).toBe(true);
    expect(CompanyAPI.saveUpdateServerBase).toHaveBeenCalledWith(7, null, {
      albatross_id: 9002,
    });
    expect(wrapper.vm.data.bases).toEqual([{ id: 2, albatross_id: 9002 }]);
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

  describe('keeping the screen up to date', () => {
    const setVisibility = state =>
      Object.defineProperty(document, 'visibilityState', {
        value: state,
        configurable: true,
      });

    afterEach(() => setVisibility('visible'));

    it('reloads silently when the tab gets focus back and nothing is open', async () => {
      CompanyAPI.getUpdateServer.mockResolvedValue({ data: payload() });
      const wrapper = await mountTab();
      CompanyAPI.getUpdateServer.mockResolvedValue({
        data: payload({ bases: [{ id: 3, albatross_id: 9003, active: true }] }),
      });

      document.dispatchEvent(new Event('visibilitychange'));
      await flushPromises();

      expect(CompanyAPI.getUpdateServer).toHaveBeenCalledTimes(2);
      expect(wrapper.vm.data.bases[0].albatross_id).toBe(9003);
      expect(wrapper.vm.isLoading).toBe(false);
      expect(wrapper.vm.lastUpdatedAt).toBeInstanceOf(Date);
    });

    it('does not reload while a form is open, while saving or while hidden', async () => {
      CompanyAPI.getUpdateServer.mockResolvedValue({ data: payload() });
      const wrapper = await mountTab();

      wrapper.vm.openSections.licenses = true;
      document.dispatchEvent(new Event('visibilitychange'));
      wrapper.vm.openSections.licenses = false;
      setVisibility('hidden');
      document.dispatchEvent(new Event('visibilitychange'));
      await flushPromises();

      expect(CompanyAPI.getUpdateServer).toHaveBeenCalledTimes(1);
    });

    it('keeps the data on screen when a background reload fails', async () => {
      CompanyAPI.getUpdateServer.mockResolvedValue({ data: payload() });
      const wrapper = await mountTab();
      CompanyAPI.getUpdateServer.mockRejectedValue({
        response: { status: 502 },
      });

      await wrapper.vm.reload();

      expect(wrapper.vm.loadFailed).toBe(false);
      expect(wrapper.vm.data.bases).toHaveLength(1);
    });

    it('stops listening to the focus event when the tab is unmounted', async () => {
      CompanyAPI.getUpdateServer.mockResolvedValue({ data: payload() });
      const wrapper = await mountTab();
      wrapper.unmount();

      document.dispatchEvent(new Event('visibilitychange'));
      await flushPromises();

      expect(CompanyAPI.getUpdateServer).toHaveBeenCalledTimes(1);
    });
  });

  describe('license modules', () => {
    it('saves a module and reloads the payload, since the Portal answers only the module', async () => {
      CompanyAPI.getUpdateServer.mockResolvedValue({ data: payload() });
      CompanyAPI.saveUpdateServerModule.mockResolvedValue({ data: { id: 5 } });
      const wrapper = await mountTab();

      const result = await wrapper.vm.saveModule(null, { code: 'TSTX' });

      expect(result).toEqual({ ok: true, message: '' });
      expect(CompanyAPI.saveUpdateServerModule).toHaveBeenCalledWith(7, null, {
        code: 'TSTX',
      });
      expect(CompanyAPI.getUpdateServer).toHaveBeenCalledTimes(2);
    });

    it('returns the Portal validation message instead of alerting', async () => {
      CompanyAPI.getUpdateServer.mockResolvedValue({ data: payload() });
      CompanyAPI.saveUpdateServerModule.mockRejectedValue({
        response: { data: { errors: ['Código já está em uso'] } },
      });
      const wrapper = await mountTab();

      const result = await wrapper.vm.saveModule(null, { code: 'DUP' });

      expect(result).toEqual({ ok: false, message: 'Código já está em uso' });
      expect(useAlert).not.toHaveBeenCalled();
      expect(CompanyAPI.getUpdateServer).toHaveBeenCalledTimes(1);
    });

    it('reorders with the ids and reloads', async () => {
      CompanyAPI.getUpdateServer.mockResolvedValue({ data: payload() });
      CompanyAPI.reorderUpdateServerModules.mockResolvedValue({ data: '' });
      const wrapper = await mountTab();

      await wrapper.vm.reorderModules([3, 1, 2]);

      expect(CompanyAPI.reorderUpdateServerModules).toHaveBeenCalledWith(
        7,
        [3, 1, 2]
      );
      expect(CompanyAPI.getUpdateServer).toHaveBeenCalledTimes(2);
    });
  });
});
