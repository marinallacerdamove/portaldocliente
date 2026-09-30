<script>
import SnackbarContainer from './components/SnackBar/Container.vue';

// PATCH LOCAL (fork) - pedido explícito: a tela de login (e o SSO dela)
// permanece sempre clara, "estática", mesmo com o SO em modo escuro - o
// resto do v3 (cadastro etc.) continua acompanhando o tema normalmente.
const LOGIN_ROUTE_NAMES = ['login', 'sso_login'];

export default {
  components: { SnackbarContainer },
  data() {
    return { theme: 'light' };
  },
  watch: {
    '$route.name': 'setColorTheme',
  },
  mounted() {
    this.setColorTheme();
    this.listenToThemeChanges();
    this.setLocale(window.chatwootConfig.selectedLocale);
  },
  methods: {
    isLoginRoute() {
      return LOGIN_ROUTE_NAMES.includes(this.$route?.name);
    },
    applyTheme(prefersDark) {
      const shouldBeDark = prefersDark && !this.isLoginRoute();
      this.theme = shouldBeDark ? 'dark' : 'light';
      document.documentElement.classList.toggle('dark', shouldBeDark);
    },
    setColorTheme() {
      this.applyTheme(
        window.matchMedia('(prefers-color-scheme: dark)').matches
      );
    },
    listenToThemeChanges() {
      const mql = window.matchMedia('(prefers-color-scheme: dark)');
      mql.onchange = e => this.applyTheme(e.matches);
    },
    setLocale(locale) {
      if (locale) {
        this.$root.$i18n.locale = locale;
      }
    },
  },
};
</script>

<template>
  <div class="h-full min-h-screen w-full antialiased" :class="theme">
    <router-view />
    <SnackbarContainer />
  </div>
</template>

<style lang="scss">
@tailwind base;
@tailwind components;
@tailwind utilities;

@import '../dashboard/assets/scss/next-colors';

html,
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
    Oxygen-Sans, Ubuntu, Cantarell, 'Helvetica Neue', sans-serif;
  @apply h-full w-full;

  input,
  select {
    outline: none;
  }
}

.text-link {
  @apply text-n-brand font-medium hover:text-n-blue-10;
}

.v-popper--theme-tooltip .v-popper__inner {
  background: black !important;
  font-size: 0.75rem;
  padding: 4px 8px !important;
  border-radius: 6px;
  font-weight: 400;
}

.v-popper--theme-tooltip .v-popper__arrow-container {
  display: none;
}
</style>
