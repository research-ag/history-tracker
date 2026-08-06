import { ExtendedChange } from "@bindings/history_be";

export const extractModuleHashes = (changes: Array<ExtendedChange>) => {
  const moduleHashes: Array<Uint8Array> = [];
  for (const change of changes) {
    if (!change.details) continue;
    if (change.details.__kind__ === "code_deployment") {
      const codeDeploymentRecord = change.details.code_deployment;
      moduleHashes.push(codeDeploymentRecord.module_hash);
    }
  }
  return [...new Set(moduleHashes)];
};
