import { usePortalAssistantAsk } from '../usePortalAssistantAsk';
import PortalAssistantAPI from 'dashboard/api/portalAssistant';
import { useAlert } from 'dashboard/composables';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/usePortalAssistant', () => ({
  usePortalAssistant: () => ({ errorMessage: (_, fallback) => fallback }),
}));
vi.mock('dashboard/api/portalAssistant', () => ({
  default: { ask: vi.fn(), getQuestion: vi.fn(), rate: vi.fn() },
}));

// Regressão B37 (auditoria 18/11): a pergunta volta na hora como "respondendo" (pending) e a tela
// consulta até a resposta chegar, sem depender do tempo de uma requisição só.
describe('usePortalAssistantAsk', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
  });
  afterEach(() => vi.useRealTimers());

  it('waits for the answer while the question is pending', async () => {
    PortalAssistantAPI.ask.mockResolvedValue({
      data: { id: 5, pending: true },
    });
    PortalAssistantAPI.getQuestion
      .mockResolvedValueOnce({ data: { id: 5, pending: true } })
      .mockResolvedValueOnce({
        data: { id: 5, pending: false, answer: 'Menu Fiscal.' },
      });
    const { ask, isAsking } = usePortalAssistantAsk();

    const result = ask('Como emito nota?');
    expect(isAsking.value).toBe(true);
    await vi.runAllTimersAsync();

    expect(await result).toEqual({
      id: 5,
      pending: false,
      answer: 'Menu Fiscal.',
    });
    expect(PortalAssistantAPI.getQuestion).toHaveBeenCalledTimes(2);
    expect(isAsking.value).toBe(false);
  });

  it('shows the Portal message when the answer fails', async () => {
    PortalAssistantAPI.ask.mockResolvedValue({
      data: { id: 5, pending: true },
    });
    PortalAssistantAPI.getQuestion.mockResolvedValue({
      data: {
        id: 5,
        pending: false,
        failed: true,
        error_message: 'Tente de novo em 1 minuto.',
      },
    });
    const { ask } = usePortalAssistantAsk();

    const result = ask('Como emito nota?');
    await vi.runAllTimersAsync();

    expect(await result).toBeNull();
    expect(useAlert).toHaveBeenCalledWith('Tente de novo em 1 minuto.');
  });

  it('gives up after the waiting limit', async () => {
    PortalAssistantAPI.ask.mockResolvedValue({
      data: { id: 5, pending: true },
    });
    PortalAssistantAPI.getQuestion.mockResolvedValue({
      data: { id: 5, pending: true },
    });
    const { ask } = usePortalAssistantAsk();

    const result = ask('Como emito nota?');
    await vi.runAllTimersAsync();

    expect(await result).toBeNull();
    expect(useAlert).toHaveBeenCalledWith('PORTAL_ASSISTANT.ASK.TIMEOUT');
  });
});
