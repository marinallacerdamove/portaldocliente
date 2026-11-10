// PATCH LOCAL (fork) - o público de uma campanha mistura etiquetas e Grupos do
// Portal. O seletor trabalha com chaves "Tipo:id" (ids de etiqueta e de grupo
// podem coincidir) e o que vai pra API é { type, id }.
export const AUDIENCE_TYPES = {
  LABEL: 'Label',
  PORTAL_GROUP: 'PortalGroup',
};

const KEY_SEPARATOR = ':';

export const audienceKey = (type, id) => `${type}${KEY_SEPARATOR}${id}`;

// Etiqueta guarda o id numérico; Grupo guarda texto ("todos" ou o id).
export const serializeAudience = keys =>
  keys.map(key => {
    const [type, ...rest] = key.split(KEY_SEPARATOR);
    const id = rest.join(KEY_SEPARATOR);
    return { type, id: type === AUDIENCE_TYPES.LABEL ? Number(id) : id };
  });
