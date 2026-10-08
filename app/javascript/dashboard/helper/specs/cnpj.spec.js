import { cnpjKey, formatCnpj, isNumericCnpj, isValidCnpj } from '../cnpj';

describe('cnpj helper', () => {
  it('keeps letters and digits in upper case as the comparison key', () => {
    expect(cnpjKey('12.abc.345/0001-95')).toBe('12ABC345000195');
    expect(cnpjKey(null)).toBe('');
  });

  it('accepts a CPF, a numeric CNPJ and an alphanumeric CNPJ', () => {
    expect(isValidCnpj('123.456.789-09')).toBe(true);
    expect(isValidCnpj('12.345.678/0001-95')).toBe(true);
    expect(isValidCnpj('12.ABC.345/01DE-35')).toBe(true);
  });

  it('rejects wrong sizes and letters in the check digits or in a CPF', () => {
    expect(isValidCnpj('')).toBe(false);
    expect(isValidCnpj('12345')).toBe(false);
    expect(isValidCnpj('12.ABC.345/01DE-3X')).toBe(false);
    expect(isValidCnpj('1234567890A')).toBe(false);
  });

  it('only looks up numeric CNPJ on BrasilAPI', () => {
    expect(isNumericCnpj('12.345.678/0001-95')).toBe(true);
    expect(isNumericCnpj('12.ABC.345/01DE-35')).toBe(false);
    expect(isNumericCnpj('123.456.789-09')).toBe(false);
  });

  it('formats a CNPJ, a CPF and leaves incomplete values as the key', () => {
    expect(formatCnpj('12345678000195')).toBe('12.345.678/0001-95');
    expect(formatCnpj('12abc34501de35')).toBe('12.ABC.345/01DE-35');
    expect(formatCnpj('12345678909')).toBe('123.456.789-09');
    expect(formatCnpj('123')).toBe('123');
  });
});
