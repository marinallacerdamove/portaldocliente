import { mount } from '@vue/test-utils';
import LabeledSelect from './LabeledSelect.vue';

const options = [
  { value: 'a', label: 'Option A' },
  { value: 'b', label: 'Option B' },
];

const mountSelect = (props = {}, attrs = {}) =>
  mount(LabeledSelect, { props: { options, ...props }, attrs });

describe('LabeledSelect', () => {
  it('wraps the untouched Select in a label with the text above it', () => {
    const wrapper = mountSelect({ label: 'Tipo', modelValue: 'a' });

    expect(wrapper.element.tagName).toBe('LABEL');
    expect(
      wrapper.element.querySelector(':scope > span').textContent.trim()
    ).toBe('Tipo');
    // raiz do Select do upstream: div.w-fit.relative > select
    const selectRoot = wrapper.element.querySelector(':scope > div.relative');
    expect(selectRoot).not.toBeNull();
    expect(selectRoot.classList.contains('!w-full')).toBe(true);
    expect(selectRoot.querySelector(':scope > select')).not.toBeNull();
  });

  it('renders no label text when none is given', () => {
    const wrapper = mountSelect({ modelValue: 'a' });

    expect(wrapper.element.querySelector(':scope > span')).toBeNull();
  });

  it('forwards options and the selected value to the select', () => {
    const wrapper = mountSelect({ modelValue: 'b' });

    expect(wrapper.findAll('option')).toHaveLength(2);
    expect(wrapper.find('select').element.value).toBe('b');
  });

  it('emits update:modelValue when the selection changes', async () => {
    const wrapper = mountSelect({ modelValue: 'a' });

    await wrapper.find('select').setValue('b');

    expect(wrapper.emitted('update:modelValue')[0]).toEqual(['b']);
  });

  it('forwards disabled to the select and keeps class on the root', () => {
    const wrapper = mountSelect({}, { disabled: true, class: 'sm:max-w-md' });

    expect(wrapper.find('select').attributes('disabled')).toBeDefined();
    expect(wrapper.classes()).toContain('sm:max-w-md');
    expect(wrapper.classes()).toContain('flex-col');
  });
});
