import { shallowMount } from '@vue/test-utils';
import CompanyUpdateServerBulkLicenses from '../CompanyUpdateServerBulkLicenses.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const modules = [
  { id: 1, code: 'STK', name: 'Estoque', active: true },
  { id: 2, code: 'OLD', name: 'Antigo', active: false },
];

const mountBulk = (saveEach, licenses = []) =>
  shallowMount(CompanyUpdateServerBulkLicenses, {
    props: { modules, licenses, saveEach },
  });

describe('CompanyUpdateServerBulkLicenses', () => {
  it('creates one license per user, in order, with the shared code, type and modules', async () => {
    const saveEach = vi.fn().mockResolvedValue({ ok: true, message: '' });
    const wrapper = mountBulk(saveEach);
    wrapper.vm.usersText = 'Ana\n\nBia\nana';
    wrapper.vm.code = '5005';
    wrapper.vm.licenseType = 'A';
    wrapper.vm.toggleModule(1, true);

    await wrapper.vm.submit();

    expect(saveEach).toHaveBeenCalledTimes(2);
    expect(saveEach.mock.calls[0]).toEqual([
      null,
      {
        user_name: 'Ana',
        code: '5005',
        license_type: 'A',
        active: true,
        license_module_ids: [1],
      },
    ]);
    expect(saveEach.mock.calls[1][1].user_name).toBe('Bia');
    expect(wrapper.vm.created).toBe(2);
    expect(wrapper.vm.failures).toEqual([]);
    expect(wrapper.vm.usersText).toBe('');
  });

  it('keeps the failed users in the box and does not lose the ones that worked', async () => {
    const saveEach = vi
      .fn()
      .mockResolvedValueOnce({ ok: true, message: '' })
      .mockResolvedValueOnce({ ok: false, message: 'Usuário em branco' })
      .mockResolvedValueOnce({ ok: true, message: '' });
    const wrapper = mountBulk(saveEach);
    wrapper.vm.usersText = 'Ana\nBia\nCaio';
    wrapper.vm.toggleModule(1, true);

    await wrapper.vm.submit();

    expect(wrapper.vm.created).toBe(2);
    expect(wrapper.vm.failures).toEqual([
      { user: 'Bia', message: 'Usuário em branco' },
    ]);
    expect(wrapper.vm.usersText).toBe('Bia');
    expect(wrapper.vm.progress).toEqual({ done: 3, total: 3 });
    expect(wrapper.vm.running).toBe(false);
  });

  it('only allows submitting with users and at least one module, and offers only active modules', () => {
    const wrapper = mountBulk(vi.fn());

    expect(wrapper.vm.canSubmit).toBeFalsy();
    wrapper.vm.usersText = 'Ana';
    expect(wrapper.vm.canSubmit).toBeFalsy();
    wrapper.vm.toggleModule(1, true);
    expect(wrapper.vm.canSubmit).toBeTruthy();
    expect(wrapper.vm.activeModules.map(mod => mod.code)).toEqual(['STK']);
  });

  it('counts the users who already have an active license, as a warning only', () => {
    const wrapper = mountBulk(vi.fn(), [
      { id: 9, user_name: 'ana', active: true },
    ]);
    wrapper.vm.usersText = 'Ana\nBia';

    expect(wrapper.vm.alreadyActive).toBe(1);
  });
});
