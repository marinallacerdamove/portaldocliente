import { mount } from '@vue/test-utils';
import CompanyUpdateServerSummary from '../CompanyUpdateServerSummary.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const summary = {
  license_count: 4,
  per_module: [
    { code: 'STK', name: 'Estoque', count: 4 },
    { code: 'FIN', name: 'Financeiro', count: 2 },
    { code: 'RH', name: 'Pessoal', count: 0 },
  ],
  combinations: [{ combination: 'STK_FIN', count: 2 }],
};

const mountSummary = (props = {}) =>
  mount(CompanyUpdateServerSummary, { props: { summary, ...props } });

describe('CompanyUpdateServerSummary', () => {
  it('shows the total, one bar per module and the combinations', () => {
    const wrapper = mountSummary();

    expect(wrapper.text()).toContain('4');
    expect(wrapper.findAll('li button')).toHaveLength(3);
    expect(wrapper.text()).toContain('STK_FIN');
  });

  it('scales each bar to the biggest module', () => {
    const bars = mountSummary()
      .findAll('li button span.block')
      .map(bar => bar.attributes('style'));

    expect(bars[0]).toContain('width: 100%');
    expect(bars[1]).toContain('width: 50%');
    expect(bars[2]).toContain('width: 0%');
  });

  it('selects a module on click and clears it on the second click', async () => {
    const wrapper = mountSummary();
    await wrapper.findAll('li button')[1].trigger('click');
    expect(wrapper.emitted('select')[0]).toEqual(['FIN']);

    await wrapper.setProps({ selected: 'FIN' });
    expect(wrapper.findAll('li button')[1].attributes('aria-pressed')).toBe(
      'true'
    );
    await wrapper.findAll('li button')[1].trigger('click');
    expect(wrapper.emitted('select')[1]).toEqual(['']);
  });

  it('does not select a module nobody uses', () => {
    expect(
      mountSummary().findAll('li button')[2].attributes('disabled')
    ).toBeDefined();
  });

  it('shows the empty message when there are no active licenses', () => {
    const wrapper = mountSummary({ summary: { license_count: 0 } });

    expect(wrapper.text()).toContain('SUMMARY.EMPTY');
    expect(wrapper.find('ul').exists()).toBe(false);
  });
});
