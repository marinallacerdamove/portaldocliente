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
      code: '5005',
      license_type: 'B',
    });
    wrapper.vm.toggleModule(1, true);
    wrapper.vm.toggleModule(2, true);
    wrapper.vm.toggleModule(1, false);

    await wrapper.vm.submit();

    expect(wrapper.props('save')).toHaveBeenCalledWith(null, {
      user_name: 'ana',
      code: '5005',
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

  const licenses = [
    {
      id: 1,
      user_name: 'Ana',
      code: '5005',
      license_type: 'A',
      active: true,
      license_module_ids: [1],
      combination: 'STK',
    },
    {
      id: 2,
      user_name: 'Bia',
      code: '5005',
      license_type: 'A',
      active: true,
      license_module_ids: [1, 2],
      combination: 'STK_FIN',
    },
    {
      id: 3,
      user_name: 'Caio',
      code: '',
      license_type: 'B',
      active: false,
      license_module_ids: [2],
      combination: 'FIN',
    },
  ];

  it('filters the list by the module picked in the totals board', () => {
    const wrapper = mountLicenses({ licenses, moduleFilter: 'FIN' });

    expect(wrapper.vm.list.visible.value.map(item => item.id)).toEqual([2, 3]);
  });

  it('groups the visible licenses by code, with the ones without code last', () => {
    const wrapper = mountLicenses({ licenses });

    expect(
      wrapper.vm.groups.map(group => [group.code, group.items.length])
    ).toEqual([
      ['5005', 2],
      ['', 1],
    ]);
  });

  it('warns about an already active user without blocking the save', async () => {
    const save = vi.fn().mockResolvedValue(true);
    const wrapper = mountLicenses({ licenses, save });

    wrapper.vm.startNew();
    wrapper.vm.draft.user_name = ' ana ';
    expect(wrapper.vm.duplicateUser).toBe(true);
    wrapper.vm.draft.license_module_ids = [1];
    await wrapper.vm.submit();

    expect(save).toHaveBeenCalled();
    wrapper.vm.startEdit(licenses[0]);
    expect(wrapper.vm.duplicateUser).toBe(false);
  });

  it('sends only the active flag when switching a license on the row', async () => {
    const save = vi.fn().mockResolvedValue(true);
    const wrapper = mountLicenses({ licenses, save });

    await wrapper.vm.toggleActive(licenses[0], false);

    expect(save).toHaveBeenCalledWith(1, { active: false });
  });

  it('tells the container when a form, the batch or the modules panel is open', async () => {
    const wrapper = mountLicenses({
      licenses,
      saveEach: vi.fn(),
      saveModule: vi.fn(),
    });

    wrapper.vm.startBulk();
    await wrapper.vm.$nextTick();
    wrapper.vm.startModules();
    await wrapper.vm.$nextTick();
    wrapper.vm.modulesOpen = false;
    await wrapper.vm.$nextTick();

    expect(wrapper.emitted('busyChange')).toEqual([[true], [false]]);
  });
});
