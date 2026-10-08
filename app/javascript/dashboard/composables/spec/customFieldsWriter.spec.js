import { saveCustomFields } from '../customFieldsWriter';

const deferred = () => {
  let resolve;
  let reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
};

const createStore = () => {
  const sent = [];
  const requests = [];
  const commits = [];
  return {
    sent,
    requests,
    commits,
    commit: vi.fn((type, payload) => commits.push(payload)),
    dispatch: vi.fn((name, payload) => {
      if (name === 'getConversation') return Promise.resolve();
      sent.push(payload.changes.campos_adicionais);
      const request = deferred();
      requests.push(request);
      return request.promise;
    }),
  };
};

describe('saveCustomFields', () => {
  it('shows the new values right away and sends them', async () => {
    const store = createStore();

    const saving = saveCustomFields(store, 1, { check: ['a'] });

    expect(store.commits).toEqual([
      {
        conversationId: 1,
        customAttributes: { campos_adicionais: { check: ['a'] } },
      },
    ]);
    expect(store.sent).toEqual([{ check: ['a'] }]);
    store.requests[0].resolve();
    await saving;
  });

  it('sends what was marked while the first request ran in one next request, with the latest state', async () => {
    const store = createStore();

    const first = saveCustomFields(store, 1, { check: ['a'] });
    const second = saveCustomFields(store, 1, { check: ['a', 'b'] });
    const third = saveCustomFields(store, 1, { check: ['a', 'b', 'c'] });
    expect(store.sent).toHaveLength(1);

    store.requests[0].resolve();
    await Promise.resolve();
    await Promise.resolve();
    expect(store.sent).toEqual([{ check: ['a'] }, { check: ['a', 'b', 'c'] }]);
    store.requests[1].resolve();

    await Promise.all([first, second, third]);
  });

  it('puts the optimistic values back after a response that was behind them', async () => {
    const store = createStore();

    const first = saveCustomFields(store, 1, { check: ['a'] });
    const second = saveCustomFields(store, 1, { check: ['a', 'b'] });
    store.commits.length = 0;
    store.requests[0].resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(store.commits).toEqual([
      {
        conversationId: 1,
        customAttributes: { campos_adicionais: { check: ['a', 'b'] } },
      },
    ]);
    store.requests[1].resolve();
    await Promise.all([first, second]);
  });

  it('reloads the conversation and rejects when the request fails', async () => {
    const store = createStore();

    const saving = saveCustomFields(store, 1, { check: ['a'] });
    store.requests[0].reject(new Error('422'));

    await expect(saving).rejects.toThrow('422');
    expect(store.dispatch).toHaveBeenCalledWith('getConversation', 1);
  });

  it('starts a new request for a later save once the queue is empty', async () => {
    const store = createStore();

    const first = saveCustomFields(store, 1, { check: ['a'] });
    store.requests[0].resolve();
    await first;
    const second = saveCustomFields(store, 1, { check: [] });
    store.requests[1].resolve();
    await second;

    expect(store.sent).toEqual([{ check: ['a'] }, { check: [] }]);
  });
});
