import { usePortalGroups } from '../usePortalGroups';
import PortalGroupsAPI from 'dashboard/api/portalGroups';

vi.mock('dashboard/api/portalGroups', () => ({ default: { get: vi.fn() } }));

describe('usePortalGroups', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('loads the groups', async () => {
    const data = [{ id: 'todos', name: 'Todos os clientes ativos' }];
    PortalGroupsAPI.get.mockResolvedValue({ data: { data } });
    const { groups, isLoading, hasError, fetchGroups } = usePortalGroups();

    const request = fetchGroups();
    expect(isLoading.value).toBe(true);
    await request;

    expect(groups.value).toEqual(data);
    expect(isLoading.value).toBe(false);
    expect(hasError.value).toBe(false);
  });

  it('flags the error and keeps the Portal message when the request fails', async () => {
    PortalGroupsAPI.get.mockRejectedValue({
      response: { data: { error: 'Portal fora do ar' } },
    });
    const { groups, hasError, errorMessage, fetchGroups } = usePortalGroups();

    await fetchGroups();

    expect(groups.value).toEqual([]);
    expect(hasError.value).toBe(true);
    expect(errorMessage.value).toBe('Portal fora do ar');
  });

  it('clears the previous error on a new attempt', async () => {
    PortalGroupsAPI.get.mockRejectedValueOnce(new Error('network'));
    PortalGroupsAPI.get.mockResolvedValueOnce({ data: { data: [] } });
    const { hasError, errorMessage, fetchGroups } = usePortalGroups();

    await fetchGroups();
    expect(hasError.value).toBe(true);
    expect(errorMessage.value).toBe('');

    await fetchGroups();
    expect(hasError.value).toBe(false);
  });
});
