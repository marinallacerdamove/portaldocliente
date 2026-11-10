import {
  AUDIENCE_TYPES,
  audienceKey,
  serializeAudience,
} from '../campaignAudience';

describe('campaignAudience', () => {
  it('builds keys that do not collide between a label and a group with the same id', () => {
    expect(audienceKey(AUDIENCE_TYPES.LABEL, 3)).toBe('Label:3');
    expect(audienceKey(AUDIENCE_TYPES.PORTAL_GROUP, 3)).toBe('PortalGroup:3');
  });

  it('serializes labels with numeric id and groups with text id', () => {
    const keys = [
      audienceKey(AUDIENCE_TYPES.LABEL, 12),
      audienceKey(AUDIENCE_TYPES.PORTAL_GROUP, 'todos'),
      audienceKey(AUDIENCE_TYPES.PORTAL_GROUP, 7),
    ];

    expect(serializeAudience(keys)).toEqual([
      { type: 'Label', id: 12 },
      { type: 'PortalGroup', id: 'todos' },
      { type: 'PortalGroup', id: '7' },
    ]);
  });

  it('returns an empty list for an empty selection', () => {
    expect(serializeAudience([])).toEqual([]);
  });
});
