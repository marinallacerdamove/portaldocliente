import { shallowMount, flushPromises } from '@vue/test-utils';
import CompanyDocuments from '../CompanyDocuments.vue';
import CompanyAPI from 'dashboard/api/companies';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/companies', () => ({
  default: { listDocuments: vi.fn() },
}));

// Regressão B76 (auditoria 18/11): trocar de empresa com a lista da anterior ainda a caminho mostrava
// os documentos da empresa anterior.
describe('CompanyDocuments switching company', () => {
  it('ignores the late answer of the previous company', async () => {
    let answerOld;
    CompanyAPI.listDocuments.mockImplementation(id =>
      id === 7
        ? new Promise(resolve => {
            answerOld = resolve;
          })
        : Promise.resolve({
            data: { files: [{ id: 2, name: 'da-empresa-8.pdf' }] },
          })
    );
    const wrapper = shallowMount(CompanyDocuments, { props: { companyId: 7 } });
    await wrapper.setProps({ companyId: 8 });
    await flushPromises();

    answerOld({ data: { files: [{ id: 1, name: 'da-empresa-7.pdf' }] } });
    await flushPromises();

    expect(wrapper.vm.files.map(file => file.name)).toEqual([
      'da-empresa-8.pdf',
    ]);
  });
});
