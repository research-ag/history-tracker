import { ExtendedChange } from "@declarations/history_be/history_be.did";

export const extractModuleHashes = (changes: Array<ExtendedChange>) => {
  const moduleHashes: Array<Uint8Array | number[]> = [];
  for (const change of changes) {
    if ("code_deployment" in change.details) {
      const codeDeploymentRecord = change.details.code_deployment;
      moduleHashes.push(codeDeploymentRecord.module_hash);
    }
  }
  return [...new Set(moduleHashes)];
};
