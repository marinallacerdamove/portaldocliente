import { shallowMount, flushPromises } from '@vue/test-utils';
import PortalContactRegistration from '../PortalContactRegistration.vue';
import ConversationApi from 'dashboard/api/inbox/conversation';
import NextButton from 'dashboard/components-next/button/Button.vue';

const dispatch = vi.fn();
const alert = vi.fn();
vi.mock('vuex', () => ({ useStore: () => ({ dispatch }) }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: msg => alert(msg) }));
vi.mock('dashboard/api/inbox/conversation', () => ({
  default: { registerPortalContact: vi.fn() },
}));

const DialogStub = {
  name: 'Dialog',
  props: ['disableConfirmButton'],
  emits: ['confirm'],
  methods: { open: vi.fn(), close: vi.fn() },
  template: '<div><slot /></div>',
};

const mountComponent = contact =>
  shallowMount(PortalContactRegistration, {
    props: { contact, conversationId: 267, companyName: 'Move Tecnologia' },
    global: { stubs: { Dialog: DialogStub }, mocks: { $t: key => key } },
  });

const contactWithoutUser = {
  id: 24,
  name: 'Implantação - Albatross ERP',
  email: null,
  phone_number: '+5537998128201',
  company_id: 4,
  custom_attributes: {},
};

describe('PortalContactRegistration', () => {
  beforeEach(() => vi.clearAllMocks());

  it('mostra "Cadastrar contato" só para contato que não é usuário do Portal', () => {
    expect(mountComponent(contactWithoutUser).text()).toContain(
      'PORTAL_CONTACT_REGISTRATION.NOT_REGISTERED'
    );
    expect(
      mountComponent({
        ...contactWithoutUser,
        custom_attributes: { portal_usuario_id: 7 },
      }).text()
    ).not.toContain('PORTAL_CONTACT_REGISTRATION.NOT_REGISTERED');
    expect(
      mountComponent({
        ...contactWithoutUser,
        identifier: 'portal_partner_3',
      }).text()
    ).not.toContain('PORTAL_CONTACT_REGISTRATION.NOT_REGISTERED');
  });

  it('cadastra no Portal com os dados digitados e atualiza o contato', async () => {
    ConversationApi.registerPortalContact.mockResolvedValue({
      data: { created: true, ticket_requested: true },
    });
    const wrapper = mountComponent(contactWithoutUser);
    await wrapper.findComponent(NextButton).vm.$emit('click');
    wrapper.vm.form.email = ' ana@cliente.com ';

    await wrapper.findComponent(DialogStub).vm.$emit('confirm');
    await flushPromises();

    expect(ConversationApi.registerPortalContact).toHaveBeenCalledWith(267, {
      name: 'Implantação - Albatross ERP',
      email: 'ana@cliente.com',
      phone: '+5537998128201',
      register_portal: true,
      complete_chatwoot: true,
    });
    expect(dispatch).toHaveBeenCalledWith('contacts/show', { id: 24 });
    expect(alert).toHaveBeenCalledWith(
      'PORTAL_CONTACT_REGISTRATION.SUCCESS_CREATED PORTAL_CONTACT_REGISTRATION.SUCCESS_TICKET'
    );
  });

  it('não deixa cadastrar no Portal sem e-mail ou sem empresa', async () => {
    const wrapper = mountComponent({ ...contactWithoutUser, company_id: null });
    await wrapper.findComponent(NextButton).vm.$emit('click');
    wrapper.vm.form.email = 'ana@cliente.com';
    await flushPromises();

    expect(
      wrapper.findComponent(DialogStub).props('disableConfirmButton')
    ).toBe(true);
  });

  it('mostra o erro devolvido pelo Portal', async () => {
    ConversationApi.registerPortalContact.mockRejectedValue({
      response: {
        data: {
          error: 'A empresa do contato ainda não está vinculada ao Portal',
        },
      },
    });
    const wrapper = mountComponent({
      ...contactWithoutUser,
      email: 'ana@cliente.com',
    });
    await wrapper.findComponent(NextButton).vm.$emit('click');
    await wrapper.findComponent(DialogStub).vm.$emit('confirm');
    await flushPromises();

    expect(alert).toHaveBeenCalledWith(
      'A empresa do contato ainda não está vinculada ao Portal'
    );
  });
});
