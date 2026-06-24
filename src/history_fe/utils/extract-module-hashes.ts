import { ExtendedChange } from "@declarations/history_be/history_be.did";

export const extractModuleHashes = (changes: Array<ExtendedChange>) => {
  const moduleHashes: Array<Uint8Array | number[]> = [];
  for (const change of changes) {
    if (change.details.length === 0) continue;
    if ("code_deployment" in change.details[0]) {
      const codeDeploymentRecord = change.details[0].code_deployment;
      moduleHashes.push(codeDeploymentRecord.module_hash);
    }
  }
  return [...new Set(moduleHashes)];
};
