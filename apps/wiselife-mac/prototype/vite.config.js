import { defineConfig } from "vite";
export default defineConfig({
  base: "./",
  esbuild: { jsx: "automatic" },
  build: {
    outDir: "dist",
    rollupOptions: {
      onwarn(warning, warn) {
        // React Server Component directives have no effect in this client-only prototype.
        if (
          warning.code === "MODULE_LEVEL_DIRECTIVE" &&
          warning.message.includes("use client")
        )
          return;
        warn(warning);
      },
      output: {
        manualChunks: {
          ui: ["@mantine/core", "@mantine/hooks", "@mantine/dates"],
        },
      },
    },
  },
});
