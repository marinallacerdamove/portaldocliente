// PATCH LOCAL (fork) - ficha do serviço: pai sem ciclo, macro só compartilhada
// e categoria padrão presa às categorias permitidas.
import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { withFullI18n } from 'test-i18n';
import ServiceFields from '../ServiceFields.vue';

withFullI18n('pt_BR');

vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  return {
    useMapGetter: () =>
      ref([
        { id: 10, name: 'Boas-vindas', visibility: 'global' },
        { id: 11, name: 'Minha macro', visibility: 'personal' },
      ]),
  };
});

vi.mock('dashboard/composables/useTicketCatalog', async () => {
  const { reactive } = await import('vue');
  const state = reactive({
    services: [
      {
        id: 1,
        parent_id: null,
        name: 'Fiscal',
        full_name: 'Fiscal',
        active: true,
      },
      {
        id: 2,
        parent_id: 1,
        name: 'NF-e',
        full_name: 'Fiscal › NF-e',
        active: true,
      },
      {
        id: 3,
        parent_id: null,
        name: 'Financeiro',
        full_name: 'Financeiro',
        active: false,
      },
    ],
    categories: [
      { id: 7, name: 'Dúvida', active: true },
      { id: 8, name: 'Erro', active: true },
    ],
  });
  return { useTicketCatalog: () => ({ state }) };
});

const mountFields = record =>
  shallowMount(ServiceFields, {
    props: {
      record: {
        id: 1,
        name: 'Fiscal',
        description: '',
        parent_id: null,
        all_categories: false,
        category_ids: [7, 8],
        default_category_id: 8,
        default_priority: null,
        macro_id: null,
        visible_to_clients: true,
        allow_finish: true,
        ...record,
      },
    },
    global: {
      stubs: {
        InfoCard: { template: '<div><slot /><slot name="actions" /></div>' },
      },
    },
  });

describe('ServiceFields.vue', () => {
  it('does not offer the service itself or its descendants as parent', () => {
    const { parentOptions } = mountFields().vm.$.setupState;
    expect(parentOptions.map(option => option.value)).toEqual(['', 3]);
    expect(parentOptions[1].label).toBe('Financeiro (inativo)');
  });

  it('offers only shared macros', () => {
    const { macroOptions } = mountFields().vm.$.setupState;
    expect(macroOptions.map(option => option.value)).toEqual(['', 10]);
  });

  it('clears the default category once it is no longer allowed', async () => {
    const wrapper = mountFields();
    const record = wrapper.props('record');
    record.category_ids = [7];
    await nextTick();
    expect(record.default_category_id).toBeNull();
  });
});
