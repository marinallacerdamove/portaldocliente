import { mount } from '@vue/test-utils';
import UpdateServerSortableTh from '../UpdateServerSortableTh.vue';

const mountTh = props =>
  mount(UpdateServerSortableTh, {
    props: { label: 'ID', sortKey: 'id', ...props },
    attachTo: document.createElement('tr'),
  });

describe('UpdateServerSortableTh', () => {
  it('aligns numeric and text headers to the start, like their values', () => {
    expect(mountTh({ numeric: true }).find('th').classes()).toContain(
      'text-left'
    );
    expect(mountTh().find('th').classes()).toContain('text-left');
  });

  it('reports the sort state and emits the key on click', async () => {
    const wrapper = mountTh({ activeKey: 'id', direction: 'desc' });

    expect(wrapper.find('th').attributes('aria-sort')).toBe('descending');
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('sort')[0]).toEqual(['id']);
  });
});
