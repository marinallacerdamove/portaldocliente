import { nextContractUpdate } from '../contractUpdate';

// Mesmos casos do spec do Portal (spec/models/empresa_contrato_spec.rb).
const contract = extra => ({
  inicio: '2025-03-10',
  periodoMeses: '12',
  ...extra,
});

describe('nextContractUpdate', () => {
  it('é o primeiro aniversário do período que ainda não passou', () => {
    expect(nextContractUpdate(contract(), new Date(2026, 10, 3))).toBe(
      '2027-03-10'
    );
  });

  it('conta o próprio dia da atualização', () => {
    expect(nextContractUpdate(contract(), new Date(2026, 2, 10))).toBe(
      '2026-03-10'
    );
    expect(nextContractUpdate(contract(), new Date(2026, 2, 11))).toBe(
      '2027-03-10'
    );
  });

  it('com início no futuro, é o primeiro período depois do início', () => {
    expect(
      nextContractUpdate(
        contract({ inicio: '2027-01-01', periodoMeses: '6' }),
        new Date(2026, 10, 3)
      )
    ).toBe('2027-07-01');
  });

  it('dia 31 cai no último dia do mês curto', () => {
    expect(
      nextContractUpdate(
        contract({ inicio: '2025-01-31', periodoMeses: '6' }),
        new Date(2025, 4, 1)
      )
    ).toBe('2025-07-31');
    expect(
      nextContractUpdate(
        contract({ inicio: '2025-08-31', periodoMeses: '6' }),
        new Date(2025, 8, 1)
      )
    ).toBe('2026-02-28');
  });

  it('é null sem início, sem período, cancelado ou depois do fim', () => {
    const today = new Date(2026, 10, 3);
    expect(nextContractUpdate(contract({ inicio: '' }), today)).toBeNull();
    expect(
      nextContractUpdate(contract({ periodoMeses: '' }), today)
    ).toBeNull();
    expect(
      nextContractUpdate(contract({ status: 'cancelado' }), today)
    ).toBeNull();
    expect(
      nextContractUpdate(contract({ fim: '2027-01-01' }), today)
    ).toBeNull();
    expect(nextContractUpdate(contract({ fim: '2027-03-10' }), today)).toBe(
      '2027-03-10'
    );
  });
});
