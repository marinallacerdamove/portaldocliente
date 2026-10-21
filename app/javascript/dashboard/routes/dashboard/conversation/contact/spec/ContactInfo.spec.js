import { shallowMount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import ContactInfo from '../ContactInfo.vue';
import PortalContactRegistration from '../PortalContactRegistration.vue';
import CompanyAPI from 'dashboard/api/companies';

const testState = vi.hoisted(() => ({
  records: {},
  show: vi.fn(),
}));

vi.mock('dashboard/api/companies', () => ({ default: { search: vi.fn() } }));
vi.mock('dashboard/stores/companies', () => ({
  useCompaniesStore: () => ({
    getRecord: id => testState.records[id],
    show: testState.show,
  }),
}));
vi.mock('dashboard/composables/useLinkedCompanies', async () => {
  const { ref } = await import('vue');
  return { useLinkedCompanies: () => ({ linkedCompanies: ref([]) }) };
});

const contactCompany = { id: 3, name: 'Move Tecnologia', customAttributes: {} };
const ticketCompany = { id: 7, name: 'Acme Ltda', customAttributes: {} };

const mountContactInfo = async ({ empresa, searchResult = [] } = {}) => {
  testState.records = { 3: contactCompany, 7: ticketCompany };
  CompanyAPI.search.mockResolvedValue({ data: { payload: searchResult } });
  const store = createStore({
    getters: {
      getSelectedChat: () => ({
        id: 12,
        custom_attributes: empresa ? { empresa } : {},
      }),
    },
    actions: { 'contacts/fetchContactableInbox': () => {} },
  });
  const wrapper = shallowMount(ContactInfo, {
    props: {
      contact: { id: 24, name: 'Ana', company_id: contactCompany.id },
    },
    global: {
      plugins: [store],
      stubs: { RouterLink: true },
      mocks: { $t: key => key, $route: { params: { accountId: 1 } } },
    },
  });
  await flushPromises();
  return wrapper;
};

describe('ContactInfo company', () => {
  // Regressão B225: o card do contato ficava sem a empresa do ticket (campo
  // Empresa da conversa), mostrando só a do contato ou nenhuma.
  describe('shown on the contact card', () => {
    it('is the company of the ticket (Empresa field) when it exists in the account', async () => {
      const wrapper = await mountContactInfo({
        empresa: 'acme ltda',
        searchResult: [{ id: 7, name: 'Acme Ltda' }],
      });

      expect(CompanyAPI.search).toHaveBeenCalledWith('acme ltda');
      expect(wrapper.vm.companyId).toBe(ticketCompany.id);
      expect(wrapper.vm.company.name).toBe('Acme Ltda');
    });

    it('falls back to the company of the contact when the ticket has no Empresa', async () => {
      const wrapper = await mountContactInfo();

      expect(CompanyAPI.search).not.toHaveBeenCalled();
      expect(wrapper.vm.companyId).toBe(contactCompany.id);
    });

    it('falls back to the company of the contact when the Empresa name matches no company', async () => {
      const wrapper = await mountContactInfo({
        empresa: 'Empresa inexistente',
        searchResult: [{ id: 9, name: 'Outra Empresa' }],
      });

      expect(wrapper.vm.companyId).toBe(contactCompany.id);
    });
  });

  // Regressão B234: "Cadastrar contato" mostrava uma empresa diferente da que
  // o cadastro usa (a do ticket, em vez da do contato).
  it('registers the contact in the Portal with the company of the contact, not the ticket one', async () => {
    const wrapper = await mountContactInfo({
      empresa: 'Acme Ltda',
      searchResult: [{ id: 7, name: 'Acme Ltda' }],
    });

    expect(wrapper.vm.company.name).toBe('Acme Ltda');
    expect(
      wrapper.findComponent(PortalContactRegistration).props('companyName')
    ).toBe('Move Tecnologia');
  });
});
