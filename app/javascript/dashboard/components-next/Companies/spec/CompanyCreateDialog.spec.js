import { shallowMount, flushPromises } from '@vue/test-utils';
import CompanyCreateDialog from '../CompanyCreateDialog.vue';
import CompanyAPI from 'dashboard/api/companies';
import { useAlert } from 'dashboard/composables';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/companies', () => ({ default: { search: vi.fn() } }));

const DialogStub = {
  name: 'Dialog',
  methods: { open: vi.fn(), close: vi.fn() },
  template: '<div><slot /></div>',
};

const validCnpj = '11.222.333/0001-81';

const mountDialog = () => {
  const wrapper = shallowMount(CompanyCreateDialog, {
    global: { stubs: { Dialog: DialogStub } },
  });
  wrapper.vm.open({ name: 'Acme Ltda', cnpj: validCnpj });
  return wrapper;
};

describe('CompanyCreateDialog', () => {
  it('creates the company when nothing is duplicated', async () => {
    CompanyAPI.search.mockResolvedValue({ data: { payload: [] } });
    const wrapper = mountDialog();

    await wrapper.vm.handleConfirm();
    await flushPromises();

    expect(wrapper.emitted('create')).toHaveLength(1);
    expect(wrapper.emitted('create')[0][0]).toMatchObject({
      name: 'Acme Ltda',
    });
  });

  it('blocks a duplicated CPF/CNPJ with a message under the field', async () => {
    CompanyAPI.search.mockResolvedValue({
      data: {
        payload: [
          { name: 'Outra', custom_attributes: { cnpj: '11222333000181' } },
        ],
      },
    });
    const wrapper = mountDialog();

    await wrapper.vm.handleConfirm();
    await flushPromises();

    expect(wrapper.vm.cnpjError).toBe('COMPANIES.CREATE.DUPLICATE_CNPJ');
    expect(wrapper.emitted('create')).toBeUndefined();
  });

  // Regressão B236: a checagem de duplicata falhava em silêncio (sem aviso de
  // erro) quando a busca de empresas dava erro.
  it('warns the user and does not create when the duplicate check fails', async () => {
    CompanyAPI.search.mockRejectedValue(new Error('500'));
    const wrapper = mountDialog();

    await wrapper.vm.handleConfirm();
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith('COMPANIES.CREATE.MESSAGES.ERROR');
    expect(wrapper.emitted('create')).toBeUndefined();
    expect(wrapper.vm.isChecking).toBe(false);
  });
});
