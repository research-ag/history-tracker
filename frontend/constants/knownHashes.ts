import { sdkModuleHashes } from "./sdkModuleHashes";

const assetMap = sdkModuleHashes.reduce<Record<string, string[]>>(
  (acc, item) => ({
    ...acc,
    [item.assetModuleHash]: acc[item.assetModuleHash]
      ? acc[item.assetModuleHash].includes(`v${item.version}`)
        ? acc[item.assetModuleHash]
        : [...acc[item.assetModuleHash], `v${item.version}`]
      : [`v${item.version}`],
  }),
  {}
);

const walletMap = sdkModuleHashes.reduce<Record<string, string[]>>(
  (acc, item) => ({
    ...acc,
    [item.walletModuleHash]: acc[item.walletModuleHash]
      ? acc[item.walletModuleHash].includes(`v${item.version}`)
        ? acc[item.walletModuleHash]
        : [...acc[item.walletModuleHash], `v${item.version}`]
      : [`v${item.version}`],
  }),
  {}
);

export const mapModuleHash = (hash: string) => {
  if (assetMap[hash]) {
    return `asset canister ${assetMap[hash].join(", ")}`;
  }

  if (walletMap[hash]) {
    return `wallet canister ${walletMap[hash].join(", ")}`;
  }

  return "";
};
