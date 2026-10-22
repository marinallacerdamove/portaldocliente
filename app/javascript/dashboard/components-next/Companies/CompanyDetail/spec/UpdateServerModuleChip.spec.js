import { shallowMount } from '@vue/test-utils';
import UpdateServerModuleChip from '../UpdateServerModuleChip.vue';

const classesOf = props =>
  shallowMount(UpdateServerModuleChip, { props }).classes();

describe('UpdateServerModuleChip', () => {
  it('always gives the same module the same color', () => {
    expect(classesOf({ code: 'STK' })).toEqual(classesOf({ code: 'STK' }));
  });

  it('shows the code and, when inactive, dims the chip', () => {
    const wrapper = shallowMount(UpdateServerModuleChip, {
      props: { code: 'FIN', name: 'Financeiro', inactive: true },
    });

    expect(wrapper.text()).toBe('FIN');
    expect(wrapper.attributes('title')).toBe('Financeiro');
    expect(wrapper.classes()).toContain('opacity-60');
  });
});
