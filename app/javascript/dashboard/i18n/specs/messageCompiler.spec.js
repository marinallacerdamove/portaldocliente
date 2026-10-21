import { createI18n } from 'vue-i18n';
import i18nMessages from 'dashboard/i18n';

const flattenKeys = (messages, prefix = '') =>
  Object.entries(messages).flatMap(([key, value]) => {
    const path = prefix ? `${prefix}.${key}` : key;
    return value && typeof value === 'object'
      ? flattenKeys(value, path)
      : [path];
  });

// Regressão B221: texto de tradução com {{variavel}} literal derrubava o
// painel inteiro, porque o compilador do vue-i18n trata "{" como início de
// placeholder e "{{" é erro de compilação.
describe.each(['en', 'pt_BR'])('vue-i18n messages (%s)', locale => {
  it('compiles every message of the bot flow screens without errors', () => {
    const errors = [];
    const spies = ['error', 'warn'].map(level =>
      vi.spyOn(console, level).mockImplementation((...args) => {
        errors.push(String(args[0]));
      })
    );
    const i18n = createI18n({
      legacy: false,
      locale,
      messages: { [locale]: i18nMessages[locale] },
      missingWarn: false,
      fallbackWarn: false,
    });

    const keys = flattenKeys({ BOT_FLOW: i18nMessages[locale].BOT_FLOW });
    // eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys
    keys.forEach(key => i18n.global.t(key));
    spies.forEach(spy => spy.mockRestore());

    expect(keys.length).toBeGreaterThan(50);
    expect(errors).toEqual([]);
  });

  it('shows the literal {{variable}} example text as written', () => {
    const i18n = createI18n({
      legacy: false,
      locale,
      messages: { [locale]: i18nMessages[locale] },
    });

    expect(
      i18n.global.t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.URL_PLACEHOLDER')
    ).toMatch(/\{\{\w+\}\}$/);
    expect(
      i18n.global.t('BOT_FLOW.EDITOR.PANEL.WEBHOOK.BODY_PLACEHOLDER')
    ).toMatch(/^\{"\w+": "\{\{\w+\}\}"\}$/);
  });
});
