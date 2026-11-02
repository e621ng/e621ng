import inject from '@rollup/plugin-inject'
import vue from '@vitejs/plugin-vue'
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath, URL } from 'node:url'
import { defineConfig, type Plugin } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

// Ruffle (the Flash emulator used for .swf posts) loads its core chunks and wasm at runtime, by file name, from
// its publicPath. Those files cannot go through the bundler, so they are emitted unchanged under a versioned
// directory, which is the publicPath FlashPlayer.ts passes to Ruffle.
const ruffleDir = fileURLToPath(new URL('./node_modules/@ruffle-rs/ruffle', import.meta.url))
const ruffleVersion: string = JSON.parse(readFileSync(join(ruffleDir, 'package.json'), 'utf8')).version
const ruffleFiles = readdirSync(ruffleDir).filter((file) => /\.(js|wasm)$/.test(file) || file.startsWith('LICENSE'))
const ruffleAssetDir = `ruffle/${ruffleVersion}/`

function ruffleAssets (): Plugin {
  return {
    name: 'ruffle-assets',
    generateBundle () {
      for (const file of ruffleFiles)
        this.emitFile({ type: 'asset', fileName: ruffleAssetDir + file, source: readFileSync(join(ruffleDir, file)) })
    },
    configureServer (server) {
      server.middlewares.use((req, res, next) => {
        const path = req.url?.split('?')[0] ?? ''
        const prefix = server.config.base + ruffleAssetDir
        const file = path.startsWith(prefix) ? path.slice(prefix.length) : ''
        if (!ruffleFiles.includes(file)) return next()
        res.setHeader('Content-Type', file.endsWith('.wasm') ? 'application/wasm' : file.endsWith('.js') ? 'text/javascript' : 'text/plain')
        res.end(readFileSync(join(ruffleDir, file)))
      })
    },
  }
}

export default defineConfig(({ mode }) => ({
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./app/javascript/src/js', import.meta.url)),
      'rrweb': fileURLToPath(new URL('./app/javascript/src/js/stubs/rrweb.js', import.meta.url)),
    },
  },
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
      include: ['**/*.js', '**/*.ts', '**/*.jsx', '**/*.tsx', '**/*.vue'],
    }),
    ruffleAssets(),
  ],
  publicDir: false, // Rails handles this
  build: {
    // This would inline small assets, but ruins css variables.
    assetsInlineLimit: 0,
    // Relatively modern browser support is required
    target: "es2018",
    sourcemap: mode === 'development',
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
    // Our Vue code uses the Options API
    __VUE_OPTIONS_API__: true,
    __RUFFLE_ASSET_DIR__: JSON.stringify(ruffleAssetDir),
  },
  server: {
    // This does not work because none of our JS files are split,
    // And causes extreme slowdown. Once we have code splitting in place, we can re-enable HMR.
    hmr: false
  }
}))
