import { fileURLToPath, URL } from "node:url";
import vue from "@vitejs/plugin-vue";
import { defineConfig } from "vitest/config";

// Standalone from vite.config.mts on purpose: that config loads vite-plugin-ruby,
// which expects the Rails toolchain and misbehaves under a bare Node test run.
// We only re-declare the module aliases the source actually uses.
export default defineConfig({
  plugins: [
    // whitespace: "preserve" mirrors vite.config.mts so templates compile identically
    vue({ template: { compilerOptions: { whitespace: "preserve" } } }),
  ],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./app/javascript/src/js", import.meta.url)),
      rrweb: fileURLToPath(new URL("./app/javascript/src/js/stubs/rrweb.js", import.meta.url)),
    },
  },
  test: {
    environment: "jsdom",
    globals: false,
    setupFiles: ["./app/javascript/test/setup.ts"],
    include: ["app/javascript/test/**/*.test.ts"],
    coverage: {
      provider: "v8",
      include: ["app/javascript/src/js/**/*.js", "app/javascript/src/js/**/*.ts"]
    },
  },
});
