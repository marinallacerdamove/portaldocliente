// PATCH LOCAL (fork) - próxima atualização do contrato da empresa, mesma regra
// de EmpresaContrato#contrato_proxima_atualizacao no Portal: início + N
// períodos, a primeira data que ainda não passou. Nil sem início/período, com
// o contrato cancelado ou quando cai depois do fim. Datas em "aaaa-mm-dd".
import { CONTRATO_STATUS_CANCELADO } from 'dashboard/constants/portalCompanyFields';

const pad = value => String(value).padStart(2, '0');
const isoDate = date =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;

export const nextContractUpdate = (
  { inicio, periodoMeses, fim, status },
  today = new Date()
) => {
  const months = Number(periodoMeses);
  if (!inicio || !months || status === CONTRATO_STATUS_CANCELADO) return null;

  const [year, month, day] = inicio.split('-').map(Number);
  // Dia 31 vira o último dia do mês curto, como o advance(months:) do Rails.
  const addMonths = count => {
    const target = new Date(year, month - 1 + count, 1);
    const lastDay = new Date(
      target.getFullYear(),
      target.getMonth() + 1,
      0
    ).getDate();
    target.setDate(Math.min(day, lastDay));
    return isoDate(target);
  };

  const todayIso = isoDate(today);
  const elapsed =
    today.getFullYear() * 12 + today.getMonth() - (year * 12 + month - 1);
  let cycles = Math.max(Math.floor(elapsed / months), 1);
  let date = addMonths(cycles * months);
  while (date < todayIso) {
    cycles += 1;
    date = addMonths(cycles * months);
  }
  return fim && date > fim ? null : date;
};
