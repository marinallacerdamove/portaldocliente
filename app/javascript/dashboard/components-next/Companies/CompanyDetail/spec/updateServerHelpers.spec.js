import {
  groupByCode,
  hasActiveUser,
  hasModule,
  isHttpLink,
  linkDomain,
  matchesSearch,
  matchesStatus,
  modulesOfLicense,
  parseBulkUsers,
  sortItems,
  statusCounts,
  toCsv,
} from '../updateServerHelpers';

describe('updateServerHelpers', () => {
  it('searches every word, ignoring case and accents', () => {
    const record = { user_name: 'José da Silva', code: '5005' };

    expect(matchesSearch(record, 'jose silva', ['user_name', 'code'])).toBe(
      true
    );
    expect(matchesSearch(record, '5005', ['user_name', 'code'])).toBe(true);
    expect(matchesSearch(record, 'jose maria', ['user_name', 'code'])).toBe(
      false
    );
    expect(matchesSearch(record, '  ', ['user_name'])).toBe(true);
  });

  it('filters and counts by status', () => {
    const items = [{ active: true }, { active: false }, { active: true }];

    expect(items.filter(item => matchesStatus(item, 'active'))).toHaveLength(2);
    expect(items.filter(item => matchesStatus(item, 'inactive'))).toHaveLength(
      1
    );
    expect(items.filter(item => matchesStatus(item, 'all'))).toHaveLength(3);
    expect(statusCounts(items)).toEqual({ active: 2, inactive: 1 });
  });

  it('sorts numbers as numbers, text without accents and keeps blanks last', () => {
    const items = [{ v: 10 }, { v: null }, { v: 9 }];
    expect(sortItems(items, 'v').map(item => item.v)).toEqual([9, 10, null]);
    expect(sortItems(items, 'v', 'desc').map(item => item.v)).toEqual([
      10,
      9,
      null,
    ]);

    const names = [{ v: 'Ângelo' }, { v: 'Bia' }, { v: 'Ana' }];
    expect(sortItems(names, 'v').map(item => item.v)).toEqual([
      'Ana',
      'Ângelo',
      'Bia',
    ]);
    expect(sortItems(names, null)).toBe(names);
  });

  it('groups by code, the licenses without code in the last group', () => {
    const groups = groupByCode([
      { id: 1, code: '' },
      { id: 2, code: '20' },
      { id: 3, code: '3' },
      { id: 4, code: '20' },
    ]);

    expect(
      groups.map(group => [group.code, group.items.map(item => item.id)])
    ).toEqual([
      ['3', [3]],
      ['20', [2, 4]],
      ['', [1]],
    ]);
  });

  it('lists the license modules in the order of the module registry', () => {
    const modules = [
      { id: 1, code: 'STK' },
      { id: 2, code: 'FIN' },
      { id: 3, code: 'PCP' },
    ];
    const license = { license_module_ids: [3, 1] };

    expect(modulesOfLicense(license, modules).map(mod => mod.code)).toEqual([
      'STK',
      'PCP',
    ]);
    expect(hasModule(license, modules, 'PCP')).toBe(true);
    expect(hasModule(license, modules, 'FIN')).toBe(false);
    expect(hasModule(license, modules, 'XXX')).toBe(false);
  });

  it('only accepts http and https links and shows their domain', () => {
    expect(isHttpLink('https://erp.exemplo.com/x')).toBe(true);
    expect(isHttpLink('ftp://erp.exemplo.com')).toBe(false);
    expect(isHttpLink('')).toBe(false);
    expect(linkDomain('https://erp.exemplo.com/x')).toBe('erp.exemplo.com');
    expect(linkDomain('erp')).toBe('');
  });

  it('detects an active user in another license, ignoring the one being edited', () => {
    const licenses = [
      { id: 1, user_name: 'Ana', active: true },
      { id: 2, user_name: 'Bia', active: false },
    ];

    expect(hasActiveUser(licenses, ' ana ')).toBe(true);
    expect(hasActiveUser(licenses, 'Ana', 1)).toBe(false);
    expect(hasActiveUser(licenses, 'Bia')).toBe(false);
    expect(hasActiveUser(licenses, '')).toBe(false);
  });

  it('builds a CSV with BOM, semicolons, quoting and no spreadsheet formulas', () => {
    const csv = toCsv(
      [{ name: 'Ana; "A"', note: '=SUM(A1)' }],
      [
        { header: 'Nome', value: row => row.name },
        { header: 'Nota', value: row => row.note },
      ]
    );

    expect(csv.charCodeAt(0)).toBe(0xfeff);
    expect(csv.slice(1)).toBe('Nome;Nota\r\n"Ana; ""A""";\'=SUM(A1)');
  });

  it('parses one user per line, ignoring blanks and repeated names', () => {
    const result = parseBulkUsers('Ana\n\n  Bia  \r\nana\nCaio Souza\n');

    expect(result).toEqual({ users: ['Ana', 'Bia', 'Caio Souza'], ignored: 1 });
    expect(parseBulkUsers('')).toEqual({ users: [], ignored: 0 });
  });
});
