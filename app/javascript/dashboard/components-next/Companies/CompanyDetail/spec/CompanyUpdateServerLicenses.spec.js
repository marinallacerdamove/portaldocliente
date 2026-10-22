import { shallowMount } from '@vue/test-utils';
import CompanyUpdateServerLicenses from '../CompanyUpdateServerLicenses.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const modules = [
  { id: 1, code: 'STK', name: 'Estoque', active: true },
  { id: 2, code: 'FIN', name: 'Financeiro', active: true },
  { id: 3, code: 'OLD', name: 'Antigo', active: false },
];

const mountLicenses = (props = {}) =>
  shallowMount(CompanyUpdateServerLicenses, {
    props: {
      licenses: [],
      modules,
      save: vi.fn().mockResolvedValue(true),
      ...props,
    },
  });

describe('CompanyUpdateServerLicenses', () => {
  it('sends the user, code, type and the chosen modules on a new license', async () => {
    const wrapper = mountLicenses();
    wrapper.vm.startNew();
    Object.assign(wrapper.vm.draft, {
      user_name: 'ana',
      code: '2773',
      license_type: 'B',
    });
    wrapper.vm.toggleModule(1, true);
    wrapper.vm.toggleModule(2, true);
    wrapper.vm.toggleModule(1, false);

    await wrapper.vm.submit();

    expect(wrapper.props('save')).toHaveBeenCalledWith(null, {
      user_name: 'ana',
      code: '2773',
      license_type: 'B',
      active: true,
      license_module_ids: [2],
    });
    expect(wrapper.vm.editingId).toBeNull();
  });

  it('edits an existing license by id and keeps the form open when the save fails', async () => {
    const save = vi.fn().mockResolvedValue(false);
    const wrapper = mountLicenses({ save });
    wrapper.vm.startEdit({
      id: 9,
      user_name: 'bia',
      code: '1',
      license_type: 'A',
      active: true,
      license_module_ids: [1],
    });

    await wrapper.vm.submit();

    expect(save).toHaveBeenCalledWith(
      9,
      expect.objectContaining({ user_name: 'bia' })
    );
    expect(wrapper.vm.editingId).toBe(9);
  });

  it('lists an inactive module only when the license being edited still has it', () => {
    const wrapper = mountLicenses();

    wrapper.vm.startNew();
    expect(wrapper.vm.selectableModules.map(mod => mod.code)).toEqual([
      'STK',
      'FIN',
    ]);

    wrapper.vm.startEdit({ id: 1, user_name: 'x', license_module_ids: [3] });
    expect(wrapper.vm.selectableModules.map(mod => mod.code)).toEqual([
      'STK',
      'FIN',
      'OLD',
    ]);
  });
});
