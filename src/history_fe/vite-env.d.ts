/// <reference types="vite/client" />

import "@icp-sdk/core/agent/canister-env";

declare module "@icp-sdk/core/agent/canister-env" {
  interface CanisterEnv {
    readonly ["PUBLIC_CANISTER_ID:history_be"]: string;
    readonly ["PUBLIC_CANISTER_ID:history_be_2"]: string;
    readonly ["PUBLIC_CANISTER_ID:metadata_directory"]: string;
    readonly ["PUBLIC_CANISTER_ID:internet_identity"]: string;
  }
}
