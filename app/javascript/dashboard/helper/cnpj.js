// PATCH LOCAL (fork) - CPF/CNPJ da empresa. A empresa daqui é espelhada no
// Portal do Cliente, que exige CPF/CNPJ e usa como chave de vínculo (mesmas
// regras de Empresa#normalize_cnpj no Portal e de Company.cnpj_key aqui):
// CPF com 11 dígitos ou CNPJ com 14 caracteres (12 alfanuméricos + 2 dígitos
// verificadores, reforma tributária). Mesma regra de formato do model Company.

// Só letras e números, em maiúsculas: a chave de comparação.
export const cnpjKey = value =>
  String(value || '')
    .replace(/[^0-9A-Za-z]/g, '')
    .toUpperCase();

export const isValidCnpj = value => {
  const key = cnpjKey(value);
  if (key.length === 11) return /^\d{11}$/.test(key);
  if (key.length === 14) return /^[0-9A-Z]{12}\d{2}$/.test(key);
  return false;
};

// A consulta na BrasilAPI só conhece CNPJ numérico.
export const isNumericCnpj = value => /^\d{14}$/.test(cnpjKey(value));

export const formatCnpj = value => {
  const key = cnpjKey(value);
  if (key.length === 14)
    return `${key.slice(0, 2)}.${key.slice(2, 5)}.${key.slice(5, 8)}/${key.slice(8, 12)}-${key.slice(12)}`;
  if (key.length === 11)
    return `${key.slice(0, 3)}.${key.slice(3, 6)}.${key.slice(6, 9)}-${key.slice(9)}`;
  return key;
};
