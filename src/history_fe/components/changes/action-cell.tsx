import { Box, Button } from "@mui/joy";
import { Principal } from "@icp-sdk/core/principal";

import { CanisterInstallMode, ExtendedChange } from "@bindings/history_be";
import { mapModuleHash } from "@fe/constants/knownHashes";
import { getSHA256Hash } from "@fe/utils/hash";

import ItemWithDetails from "./item-with-details";

interface ActionCellProps {
  change: ExtendedChange;
  metadataMap: Record<string, Array<Principal>>;
  onViewMetadata: (moduleHash: Uint8Array) => void;
}

const ActionCell = ({
  change,
  metadataMap,
  onViewMetadata,
}: ActionCellProps) => {
  if (change.details?.__kind__ === "creation")
    return (
      <ItemWithDetails
        title="Creation"
        details={
          <Box sx={{ overflowWrap: "break-word" }}>
            <Box sx={{ fontWeight: 600 }}>Controllers:</Box>
            <Box component="ul">
              {change.details.creation.controllers.map((c, i) => (
                <Box key={i} component="li">
                  {c.toText()}
                </Box>
              ))}
            </Box>
          </Box>
        }
      />
    );
  if (change.details?.__kind__ === "code_deployment") {
    const codeDeploymentRecord = change.details.code_deployment;
    const getMode = () => {
      if (codeDeploymentRecord.mode === CanisterInstallMode.reinstall)
        return "Reinstall";
      if (codeDeploymentRecord.mode === CanisterInstallMode.upgrade)
        return "Upgrade";
      if (codeDeploymentRecord.mode === CanisterInstallMode.install)
        return "Install";
    };
    const moduleHash = getSHA256Hash(codeDeploymentRecord.module_hash);
    const principalsWithMetadata =
      metadataMap[codeDeploymentRecord.module_hash.join(",")] ?? [];
    return (
      <ItemWithDetails
        title={getMode()!}
        hash={moduleHash}
        details={
          <Box sx={{ overflowWrap: "break-word" }}>
            <Box>
              <Box
                sx={{
                  display: "inline",
                  fontWeight: 600,
                }}
              >
                Module hash:
              </Box>{" "}
              {moduleHash}
            </Box>
            {mapModuleHash(moduleHash) && (
              <Box>
                <Box
                  sx={{
                    display: "inline",
                    fontWeight: 600,
                  }}
                >
                  Module hash is known:
                </Box>{" "}
                {mapModuleHash(moduleHash)}
              </Box>
            )}
            {principalsWithMetadata.length ? (
              <Box sx={{ marginTop: "8px" }}>
                <Button
                  onClick={() => {
                    onViewMetadata(codeDeploymentRecord.module_hash);
                  }}
                  size="sm"
                >
                  Wasm metadata
                </Button>
              </Box>
            ) : (
              <Box>
                <Box
                  sx={{
                    display: "inline",
                    fontWeight: 600,
                  }}
                >
                  Wasm metadata:
                </Box>{" "}
                None
              </Box>
            )}
          </Box>
        }
      />
    );
  }
  if (change.details?.__kind__ === "controllers_change")
    return (
      <ItemWithDetails
        title="Controllers change"
        details={
          <Box sx={{ overflowWrap: "break-word" }}>
            <Box sx={{ fontWeight: 600 }}>Controllers:</Box>
            <Box component="ul">
              {change.details.controllers_change.controllers.map((c, i) => (
                <Box key={i} component="li">
                  {c.toText()}
                </Box>
              ))}
            </Box>
          </Box>
        }
      />
    );
  if (change.details?.__kind__ === "code_uninstall") return "Code uninstall";
};

export default ActionCell;
