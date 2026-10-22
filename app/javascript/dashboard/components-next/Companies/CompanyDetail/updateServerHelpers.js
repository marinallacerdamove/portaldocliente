// PATCH LOCAL (fork) - lógica pura das listas da aba Update Server (bases e
// licenças): busca, filtro de status, ordenação, agrupamento, CSV e o lote de
// usuários. Fica fora dos componentes pra ser testada sem montar tela.

export const STATUS_FILTERS = ['all', 'active', 'inactive'];

const normalize = value =>
  String(value ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim();

// Todas as palavras da busca precisam aparecer em algum dos campos.
export const matchesSearch = (record, query, keys) => {
  const words = normalize(query).split(/\s+/).filter(Boolean);
  if (!words.length) return true;
  const haystack = keys.map(key => normalize(record[key])).join(' ');
  return words.every(word => haystack.includes(word));
};

export const matchesStatus = (record, status) => {
  if (status === 'active') return !!record.active;
  if (status === 'inactive') return !record.active;
  return true;
};

export const statusCounts = items => {
  const active = items.filter(item => item.active).length;
  return { active, inactive: items.length - active };
};

// Número com número, texto com texto (sem diferenciar acento e maiúscula);
// vazio vai sempre pro fim, na ordem que for.
export const sortItems = (items, key, direction = 'asc') => {
  if (!key) return items;
  const factor = direction === 'desc' ? -1 : 1;
  const isBlank = value =>
    value === null || value === undefined || value === '';
  return [...items].sort((a, b) => {
    const left = a[key];
    const right = b[key];
    if (isBlank(left) && isBlank(right)) return 0;
    if (isBlank(left)) return 1;
    if (isBlank(right)) return -1;
    if (typeof left === 'number' && typeof right === 'number')
      return (left - right) * factor;
    return (
      normalize(left).localeCompare(normalize(right), undefined, {
        numeric: true,
      }) * factor
    );
  });
};

// Licenças sem código ficam num grupo só, no fim.
export const groupByCode = licenses => {
  const groups = new Map();
  licenses.forEach(license => {
    const code = (license.code || '').trim();
    if (!groups.has(code)) groups.set(code, []);
    groups.get(code).push(license);
  });
  return [...groups.entries()]
    .sort(([a], [b]) => {
      if (!a) return 1;
      if (!b) return -1;
      return a.localeCompare(b, undefined, { numeric: true });
    })
    .map(([code, items]) => ({ code, items }));
};

// Módulos da licença na ordem do cadastro de módulos.
export const modulesOfLicense = (license, modules) =>
  modules.filter(mod => (license.license_module_ids || []).includes(mod.id));

export const hasModule = (license, modules, code) => {
  const mod = modules.find(item => item.code === code);
  return !!mod && (license.license_module_ids || []).includes(mod.id);
};

export const linkDomain = link => {
  try {
    return new URL(link).hostname;
  } catch {
    return '';
  }
};

export const isHttpLink = link => /^https?:\/\//i.test(link || '');

// Usuário já ativo em outra licença da empresa (só aviso, não bloqueia).
export const hasActiveUser = (licenses, userName, exceptId = null) => {
  const wanted = normalize(userName);
  if (!wanted) return false;
  return licenses.some(
    license =>
      license.active &&
      license.id !== exceptId &&
      normalize(license.user_name) === wanted
  );
};

const CSV_BOM = String.fromCharCode(0xfeff);

// Células que o Excel leria como fórmula ganham um apóstrofo na frente.
const csvCell = value => {
  let text = String(value ?? '');
  if (/^[=+\-@\t\r]/.test(text)) text = `'${text}`;
  return /[",\n\r;]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
};

// columns: [{ header, value: record => string }]. BOM no começo pro Excel
// abrir o acento certo.
export const toCsv = (rows, columns) => {
  const lines = [
    columns.map(column => csvCell(column.header)).join(';'),
    ...rows.map(row =>
      columns.map(column => csvCell(column.value(row))).join(';')
    ),
  ];
  return `${CSV_BOM}${lines.join('\r\n')}`;
};

// Lote: um usuário por linha. Linha vazia e nome repetido (sem diferenciar
// maiúscula) são ignorados; devolve também quantos foram ignorados.
export const parseBulkUsers = text => {
  const seen = new Set();
  const users = [];
  let ignored = 0;
  String(text ?? '')
    .split(/\r?\n/)
    .forEach(line => {
      const name = line.trim().replace(/\s+/g, ' ');
      if (!name) return;
      const key = normalize(name);
      if (seen.has(key)) {
        ignored += 1;
        return;
      }
      seen.add(key);
      users.push(name);
    });
  return { users, ignored };
};
