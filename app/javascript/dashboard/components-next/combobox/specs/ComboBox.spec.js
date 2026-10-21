import { mount } from '@vue/test-utils';
import ComboBox from '../ComboBox.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const options = [
  { value: 'urgent', label: 'Urgente' },
  { value: 'high', label: 'Alta' },
];

// Regressão B218: clicar num dropdown (ex. Urgência) dentro do formulário do
// novo ticket submetia o formulário e criava o ticket antes da hora.
describe('ComboBox inside a form', () => {
  const onSubmit = vi.fn();
  let form;
  let wrapper;

  beforeEach(() => {
    onSubmit.mockClear();
    form = document.createElement('form');
    form.addEventListener('submit', event => {
      event.preventDefault();
      onSubmit();
    });
    const submitButton = document.createElement('button');
    submitButton.type = 'submit';
    form.appendChild(submitButton);
    document.body.appendChild(form);
    wrapper = mount(ComboBox, {
      attachTo: form,
      props: { options, modelValue: '' },
      global: {
        stubs: { OnClickOutside: { template: '<div><slot /></div>' } },
      },
    });
  });

  afterEach(() => {
    wrapper.unmount();
    form.remove();
  });

  it('does not submit the form when opening the dropdown or picking an option', async () => {
    await wrapper.find('button').trigger('click');
    await wrapper.find('li[role="option"]').trigger('click');

    expect(wrapper.emitted('update:modelValue')[0]).toEqual(['urgent']);
    expect(onSubmit).not.toHaveBeenCalled();
  });
});
