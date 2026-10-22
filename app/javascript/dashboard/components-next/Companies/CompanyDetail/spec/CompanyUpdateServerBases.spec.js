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
      albatross_id: 9001,
      display_code: 1,
      display_name: 'BASE EXEMPLO',
      link: 'https://erp.test/9001',
      active: false,
      created_at: 'x',
    });

    await wrapper.vm.submit();

    const [baseId, attributes] = save.mock.calls[0];
    expect(baseId).toBe(5);
    expect(attributes).toEqual({
      albatross_id: 9001,
      display_code: 1,
      razao_social: '',
      display_name: 'BASE EXEMPLO',
      database_name: '',
      link: 'https://erp.test/9001',
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

  const sampleBases = [
    {
      id: 1,
      albatross_id: 9001,
      display_name: 'Base Exemplo',
      database_name: 'erp9001_exemplo',
      documento: '11444777000161',
      active: true,
    },
    {
      id: 2,
      albatross_id: 9002,
      display_name: 'Outra Base',
      database_name: 'erp9002_outra',
      documento: '',
      active: false,
    },
  ];

  it('filters by search and by status, and counts active and inactive', () => {
    const wrapper = shallowMount(CompanyUpdateServerBases, {
      props: { bases: sampleBases, save: vi.fn() },
    });

    expect(wrapper.vm.list.counts.value).toEqual({ active: 1, inactive: 1 });
    wrapper.vm.list.search.value = 'exemplo';
    expect(wrapper.vm.list.visible.value.map(item => item.id)).toEqual([1]);
    wrapper.vm.list.search.value = '';
    wrapper.vm.list.status.value = 'inactive';
    expect(wrapper.vm.list.visible.value.map(item => item.id)).toEqual([2]);
  });

  it('sends only the active flag when switching a base on the row', async () => {
    const save = vi.fn().mockResolvedValue(true);
    const wrapper = shallowMount(CompanyUpdateServerBases, {
      props: { bases: sampleBases, save },
    });

    await wrapper.vm.toggleActive(sampleBases[0], false);

    expect(save).toHaveBeenCalledWith(1, { active: false });
    expect(wrapper.vm.togglingId).toBeNull();
  });

  it('tells the container when a form is open or closed', async () => {
    const wrapper = shallowMount(CompanyUpdateServerBases, {
      props: { bases: sampleBases, save: vi.fn() },
    });

    wrapper.vm.startNew();
    await wrapper.vm.$nextTick();
    wrapper.vm.cancel();
    await wrapper.vm.$nextTick();

    expect(wrapper.emitted('busyChange')).toEqual([[true], [false]]);
  });
});
