import { defineConfig } from "vitest/config"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = path.dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  test: {
    name: "fred",
    environment: "jsdom",
    include: ["test/javascript/**/*.{test,spec}.js"],
    globals: false,
  },
  resolve: {
    alias: {
      controllers: path.resolve(root, "app/javascript/controllers"),
    },
  },
})
