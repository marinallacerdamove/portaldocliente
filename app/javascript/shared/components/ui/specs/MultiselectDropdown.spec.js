import { mount } from '@vue/test-utils';
import MultiselectDropdown from '../MultiselectDropdown.vue';
import MultiselectDropdownItems from '../MultiselectDropdownItems.vue';

const options = [
  { id: 1, name: 'Urgente' },
  { id: 2, name: 'Alta' },
];

// Regressão B218: clicar num dropdown (ex. Urgência) dentro do formulário do
// ticket submetia o formulário e criava o ticket antes da hora.
describe('MultiselectDropdown inside a form', () => {
  const onSubmit = vi.fn();
  let form;
  let wrapper;

  const mountInForm = (component, props) => {
    form = document.createElement('form');
    form.addEventListener('submit', event => {
      event.preventDefault();
      onSubmit();
    });
    document.body.appendChild(form);
    wrapper = mount(component, {
      attachTo: form,
      props,
      global: {
        stubs: { OnClickOutside: { template: '<div><slot /></div>' } },
      },
    });
  };

  beforeEach(() => onSubmit.mockClear());

  afterEach(() => {
    wrapper.unmount();
    form.remove();
  });

  it('does not submit the form when opening or closing the dropdown', async () => {
    mountInForm(MultiselectDropdown, {
      options,
      selectedItem: null,
      hasThumbnail: false,
    });
    const buttons = wrapper.findAll('button');

    expect(buttons.length).toBeGreaterThan(0);
    buttons.forEach(button => expect(button.attributes('type')).toBe('button'));
    await Promise.all(buttons.map(button => button.trigger('click')));
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('does not submit the form when picking an option', async () => {
    mountInForm(MultiselectDropdownItems, {
      options,
      hasThumbnail: false,
    });
    const optionButton = wrapper
      .findAll('button')
      .find(button => button.text().includes('Alta'));

    expect(optionButton.attributes('type')).toBe('button');
    await optionButton.trigger('click');

    expect(wrapper.emitted('select')[0]).toEqual([options[1]]);
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('does not submit the form when pressing Enter in the search field', () => {
    mountInForm(MultiselectDropdownItems, { options, hasThumbnail: false });
    const event = new KeyboardEvent('keydown', {
      key: 'Enter',
      bubbles: true,
      cancelable: true,
    });

    wrapper.find('input[type="text"]').element.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(true);
  });
});
