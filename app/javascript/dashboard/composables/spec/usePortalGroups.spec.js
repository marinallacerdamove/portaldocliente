import { portalGroupsErrorMessage, usePortalGroups } from '../usePortalGroups';
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

  it('asks the inactive groups too when all is true and only the active ones otherwise', async () => {
    PortalGroupsAPI.get.mockResolvedValue({ data: { data: [] } });
    const { fetchGroups } = usePortalGroups();

    await fetchGroups();
    await fetchGroups({ all: true });

    expect(PortalGroupsAPI.get).toHaveBeenNthCalledWith(1, { all: false });
    expect(PortalGroupsAPI.get).toHaveBeenNthCalledWith(2, { all: true });
  });

  it('turns the Portal validation errors into one message', () => {
    expect(
      portalGroupsErrorMessage({
        response: { data: { errors: ['Nome vazio', 'Nome repetido'] } },
      })
    ).toBe('Nome vazio Nome repetido');
    expect(
      portalGroupsErrorMessage({ response: { data: { error: 'Portal fora' } } })
    ).toBe('Portal fora');
    expect(portalGroupsErrorMessage(new Error('network'))).toBeUndefined();
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
