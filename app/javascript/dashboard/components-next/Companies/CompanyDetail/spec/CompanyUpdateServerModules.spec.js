import { shallowMount, flushPromises } from '@vue/test-utils';
import CompanyUpdateServerModules from '../CompanyUpdateServerModules.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const modules = [
  { id: 1, code: 'STK', name: 'Estoque', active: true },
  { id: 2, code: 'FIN', name: 'Financeiro', active: true },
  { id: 3, code: 'PCP', name: 'Producao', active: false },
];

const ok = { ok: true, message: '' };

const mountModules = (props = {}) =>
  shallowMount(CompanyUpdateServerModules, {
    props: {
      modules,
      saveModule: vi.fn().mockResolvedValue(ok),
      reorderModules: vi.fn().mockResolvedValue(ok),
      ...props,
    },
  });

describe('CompanyUpdateServerModules', () => {
  it('adds a module with code and name and clears the form', async () => {
    const wrapper = mountModules();
    wrapper.vm.draft = { code: 'TSTX', name: 'Teste X' };

    await wrapper.vm.add();

    expect(wrapper.props('saveModule')).toHaveBeenCalledWith(null, {
      code: 'TSTX',
      name: 'Teste X',
    });
    expect(wrapper.vm.draft).toEqual({ code: '', name: '' });
  });

  it('keeps the form and shows the Portal message when adding fails', async () => {
    const saveModule = vi
      .fn()
      .mockResolvedValue({ ok: false, message: 'Código já está em uso' });
    const wrapper = mountModules({ saveModule });
    wrapper.vm.draft = { code: 'STK', name: '' };

    await wrapper.vm.add();
    await flushPromises();

    expect(wrapper.vm.error).toBe('Código já está em uso');
    expect(wrapper.vm.draft.code).toBe('STK');
  });

  it('renames only when the name really changed, and turns a module on or off', async () => {
    const wrapper = mountModules();

    wrapper.vm.renaming = { 1: 'Estoque' };
    await wrapper.vm.rename(modules[0]);
    expect(wrapper.props('saveModule')).not.toHaveBeenCalled();

    wrapper.vm.renaming = { 1: 'Estoque novo' };
    await wrapper.vm.rename(modules[0]);
    expect(wrapper.props('saveModule')).toHaveBeenCalledWith(1, {
      name: 'Estoque novo',
    });

    await wrapper.vm.toggle(modules[2], true);
    expect(wrapper.props('saveModule')).toHaveBeenCalledWith(3, {
      active: true,
    });
  });

  it('reorders by sending the new order of the ids', async () => {
    const wrapper = mountModules();

    await wrapper.vm.move(1, -1);
    await wrapper.vm.move(0, 1);

    expect(wrapper.props('reorderModules').mock.calls).toEqual([
      [[2, 1, 3]],
      [[2, 1, 3]],
    ]);
  });
});
