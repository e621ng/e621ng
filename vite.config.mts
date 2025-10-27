import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import vue from '@vitejs/plugin-vue'
import inject from '@rollup/plugin-inject'

export default defineConfig({
  plugins: [
    RubyPlugin(),
    vue({
      template: {
        compilerOptions: {
          whitespace: 'preserve'
        }
      }
    }),
    inject({
      $: 'jquery',
      jQuery: 'jquery',
    }),
  ],
  publicDir: false, // Rails handles this
  build: {
    // This would inline small assets, but ruins css variables.
    assetsInlineLimit: 0,
  },
  css: {
    preprocessorOptions: {
      scss: {
        // TODO: Migrate away from SASS @import to either @use / @forward or css variables
        silenceDeprecations: ['import', 'global-builtin', 'color-functions', 'legacy-js-api']
      }
    }
  },
  define: {
    // TODO: Migrate Vue components from Options API to Composition API
    __VUE_OPTIONS_API__: true
  },
  server: {
    // This does not work because none of our JS files are split,
    // And causes extreme slowdown. Once we have code splitting in place, we can re-enable HMR.
    hmr: false
  }
})
