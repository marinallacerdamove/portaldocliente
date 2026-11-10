import { ref } from 'vue';
import { shallowMount } from '@vue/test-utils';
import WhatsAppCampaignForm from '../WhatsAppCampaignForm.vue';

const mockGroups = ref([]);
const mockHasError = ref(false);
const mockFetchGroups = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: name =>
    ref(
      {
        'campaigns/getUIFlags': { isCreating: false },
        'labels/getLabels': [{ id: 3, title: 'vip' }],
        'inboxes/getWhatsAppInboxes': [],
        'inboxes/getFilteredWhatsAppTemplates': () => [],
      }[name]
    ),
}));
vi.mock('dashboard/composables/usePortalGroups', () => ({
  usePortalGroups: () => ({
    groups: mockGroups,
    hasError: mockHasError,
    fetchGroups: mockFetchGroups,
  }),
}));

const mountForm = () => shallowMount(WhatsAppCampaignForm);

describe('WhatsAppCampaignForm audience', () => {
  beforeEach(() => {
    mockGroups.value = [
      { id: 'todos', name: 'Todos os clientes ativos', recipients_count: 10 },
      { id: 3, name: 'Clientes VIP', recipients_count: 4 },
    ];
    mockHasError.value = false;
    vi.clearAllMocks();
  });

  it('loads the Portal groups when the form opens', () => {
    mountForm();

    expect(mockFetchGroups).toHaveBeenCalledTimes(1);
  });

  it('offers the groups first and then the labels, with keys that do not collide', () => {
    const wrapper = mountForm();

    expect(wrapper.vm.audienceList.map(option => option.value)).toEqual([
      'PortalGroup:todos',
      'PortalGroup:3',
      'Label:3',
    ]);
    expect(wrapper.vm.audienceList[0].label).toContain(
      'Todos os clientes ativos'
    );
  });

  it('sends groups as PortalGroup and labels as Label', () => {
    const wrapper = mountForm();
    wrapper.vm.state.selectedAudience = [
      'PortalGroup:todos',
      'PortalGroup:3',
      'Label:3',
    ];

    expect(wrapper.vm.prepareCampaignDetails().audience).toEqual([
      { type: 'PortalGroup', id: 'todos' },
      { type: 'PortalGroup', id: '3' },
      { type: 'Label', id: 3 },
    ]);
  });

  it('keeps the labels available and warns when the Portal is down', () => {
    mockGroups.value = [];
    mockHasError.value = true;
    const wrapper = mountForm();

    expect(wrapper.vm.audienceList.map(option => option.value)).toEqual([
      'Label:3',
    ]);
    expect(wrapper.text()).toContain(
      'CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.GROUPS_ERROR'
    );
  });
});
