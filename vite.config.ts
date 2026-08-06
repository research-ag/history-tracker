/// <reference types="vitest" />
import { execSync } from "child_process";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import tsconfigPaths from "vite-tsconfig-paths";
import { icpBindgen } from "@icp-sdk/bindgen/plugins/vite";

const ICP_ENVIRONMENT = process.env.ICP_ENVIRONMENT || "local";
// All backend canisters the frontend needs to access.
const CANISTER_NAMES = ["history_be", "history_be_2", "metadata_directory", "internet_identity"];

function getCanisterId(name: string): string {
  return execSync(`icp canister status ${name} -e ${ICP_ENVIRONMENT} --id-only`, {
    encoding: "utf-8",
    stdio: "pipe",
  }).trim();
}

function getDevServerConfig() {
  const networkStatus = JSON.parse(
    execSync(`icp network status -e ${ICP_ENVIRONMENT} --json`, {
      encoding: "utf-8",
    }),
  );
  const canisterParams = CANISTER_NAMES.map(
    (name) => `PUBLIC_CANISTER_ID:${name}=${getCanisterId(name)}`,
  ).join("&");
  return {
    headers: {
      "Set-Cookie": `ic_env=${encodeURIComponent(
        `${canisterParams}&ic_root_key=${networkStatus.root_key}`,
      )}; SameSite=Lax;`,
    },
    proxy: {
      "/api": { target: networkStatus.api_url, changeOrigin: true },
    },
  };
}

export default defineConfig(({ command }) => ({
  root: "src/history_fe",
  build: {
    outDir: "../../dist",
    emptyOutDir: true,
  },
  optimizeDeps: {
    esbuildOptions: {
      define: {
        global: "globalThis",
      },
    },
  },
  plugins: [
    react(),
    tsconfigPaths(),
    icpBindgen({
      didFile: "./src/history_be/history_be.did",
      outDir: "./src/history_fe/bindings",
    }),
    icpBindgen({
      didFile: "./src/metadata_directory/metadata_directory.did",
      outDir: "./src/history_fe/bindings",
    }),
  ],
  ...(command === "serve" ? { server: getDevServerConfig() } : {}),
}));
