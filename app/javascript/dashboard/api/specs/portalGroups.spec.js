import portalGroupsAPI from '../portalGroups';
import ApiClient from '../ApiClient';

describe('#PortalGroupsAPI', () => {
  it('creates correct instance', () => {
    expect(portalGroupsAPI).toBeInstanceOf(ApiClient);
    expect(portalGroupsAPI).toHaveProperty('get');
    expect(portalGroupsAPI).toHaveProperty('show');
    expect(portalGroupsAPI).toHaveProperty('memberOptions');
    expect(portalGroupsAPI).toHaveProperty('create');
    expect(portalGroupsAPI).toHaveProperty('update');
  });

  describe('API calls', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
      vi.clearAllMocks();
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('#get asks only the active groups by default', () => {
      portalGroupsAPI.get();
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/portal_groups', {
        params: {},
      });
    });

    it('#get asks the inactive groups too with all', () => {
      portalGroupsAPI.get({ all: true });
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/portal_groups', {
        params: { all: 1 },
      });
    });

    it('#show accepts the automatic group id', () => {
      portalGroupsAPI.show('todos');
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/portal_groups/todos');
    });

    it('#options fetches the companies and contacts that can join a group', () => {
      portalGroupsAPI.memberOptions();
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/portal_groups/options'
      );
    });

    it('#create wraps the attributes in client_group', () => {
      portalGroupsAPI.create({ name: 'VIP' });
      expect(axiosMock.post).toHaveBeenCalledWith('/api/v1/portal_groups', {
        client_group: { name: 'VIP' },
      });
    });

    it('#update patches the group with the complete lists wrapped in client_group', () => {
      portalGroupsAPI.update(3, { empresa_ids: [1, 2], partner_ids: [] });
      expect(axiosMock.patch).toHaveBeenCalledWith('/api/v1/portal_groups/3', {
        client_group: { empresa_ids: [1, 2], partner_ids: [] },
      });
    });
  });
});
