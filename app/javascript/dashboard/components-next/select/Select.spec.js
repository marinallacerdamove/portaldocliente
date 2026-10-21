import { mount } from '@vue/test-utils';
import Select from './Select.vue';

const options = [
  { value: 'a', label: 'Opção A' },
  { value: 'b', label: 'Opção B' },
];

// Regressão B238: o Select do core foi alterado (rótulo próprio, raiz em
// coluna) e quebrou o estilo de telas nativas do Chatwoot, que estilizam a
// raiz dele com [&>select]. Este spec trava o contrato do upstream; o fork usa
// LabeledSelect para a variante com rótulo.
describe('Select (upstream contract)', () => {
  it('has the select as a direct child of a w-fit root, like upstream', () => {
    const wrapper = mount(Select, { props: { options } });

    expect(wrapper.element.tagName).toBe('DIV');
    expect(wrapper.classes()).toEqual(
      expect.arrayContaining(['w-fit', 'relative'])
    );
    expect(wrapper.element.querySelector(':scope > select')).not.toBeNull();
  });

  it('does not render its own label element', () => {
    const wrapper = mount(Select, {
      props: { options },
      attrs: { label: 'X' },
    });

    expect(wrapper.find('label').exists()).toBe(false);
  });

  it('keeps the select without an id the caller did not give', () => {
    const wrapper = mount(Select, { props: { options } });

    expect(wrapper.find('select').attributes('id')).toBeUndefined();
  });

  it('updates v-model and renders the placeholder as a disabled option', async () => {
    const wrapper = mount(Select, {
      props: { options, placeholder: 'Escolha', modelValue: '' },
    });

    expect(wrapper.find('option[disabled]').text()).toBe('Escolha');
    await wrapper.find('select').setValue('b');

    expect(wrapper.emitted('update:modelValue')[0]).toEqual(['b']);
  });
});
