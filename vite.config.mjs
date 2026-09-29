import { defineConfig } from 'vite';
import RubyPlugin from 'vite-plugin-ruby';
import vue from '@vitejs/plugin-vue';

const rubyPlugins = RubyPlugin();
const safeRubyPlugins = Array.isArray(rubyPlugins) ? rubyPlugins : [rubyPlugins];

safeRubyPlugins.forEach((plugin) => {
  if (plugin && typeof plugin.config === 'function') {
    const originalConfig = plugin.config;
    plugin.config = function (userConfig, env) {
      const ctx = this ?? { meta: {} };
      return originalConfig.call(ctx, userConfig, env);
    };
  }
});

export default defineConfig({
  plugins: [
    ...safeRubyPlugins,
    vue()
  ],
  resolve: {
    alias: {
      'vue': 'vue/dist/vue.esm-bundler',
    },
  }
})
