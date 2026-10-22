import { shallowMount } from '@vue/test-utils';
import CompanyUpdateServerBases from '../CompanyUpdateServerBases.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

describe('CompanyUpdateServerBases', () => {
  it('sends only the base fields, never the id, when editing', async () => {
    const save = vi.fn().mockResolvedValue(true);
    const wrapper = shallowMount(CompanyUpdateServerBases, {
      props: { bases: [], save },
    });
    wrapper.vm.startEdit({
      id: 5,
      albatross_id: 156,
      display_code: 1,
      display_name: 'FANTASMINHA',
      link: 'https://erp.test/156',
      active: false,
      created_at: 'x',
    });

    await wrapper.vm.submit();

    const [baseId, attributes] = save.mock.calls[0];
    expect(baseId).toBe(5);
    expect(attributes).toEqual({
      albatross_id: 156,
      display_code: 1,
      razao_social: '',
      display_name: 'FANTASMINHA',
      database_name: '',
      link: 'https://erp.test/156',
      documento: '',
      active: false,
    });
  });

  it('only links http and https addresses', () => {
    const wrapper = shallowMount(CompanyUpdateServerBases, {
      props: { bases: [], save: vi.fn() },
    });

    expect(wrapper.vm.isHttpLink('https://erp.test')).toBe(true);
    expect(wrapper.vm.isHttpLink('ftp://erp.test')).toBe(false);
    expect(wrapper.vm.isHttpLink('')).toBe(false);
  });
});
