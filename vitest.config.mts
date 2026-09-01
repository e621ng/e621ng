import { fileURLToPath, URL } from "node:url";
import { defineConfig } from "vitest/config";

// Standalone from vite.config.mts on purpose: that config loads vite-plugin-ruby,
// which expects the Rails toolchain and misbehaves under a bare Node test run.
// We only re-declare the module aliases the source actually uses.
export default defineConfig({
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
  },
});
