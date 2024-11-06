import { Box, Button } from "@mui/joy";

import { ExtendedChange } from "@declarations/history_be/history_be.did";
import { mapModuleHash } from "@fe/constants/knownHashes";
import { getSHA256Hash } from "@fe/utils/hash";
import { WasmMetadata } from "@declarations/cmm_be/cmm_be.did";

import ItemWithDetails from "./item-with-details";

interface ActionCellProps {
  change: ExtendedChange;
  wasmMetadata: WasmMetadata | null;
  onViewMetadata: (wasmMetadata: WasmMetadata) => void;
}

const ActionCell = ({
  change,
  wasmMetadata,
  onViewMetadata,
}: ActionCellProps) => {
  if ("creation" in change.details)
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
  if ("code_deployment" in change.details) {
    const codeDeploymentRecord = change.details.code_deployment;
    const getMode = () => {
      if ("reinstall" in codeDeploymentRecord.mode) return "Reinstall";
      if ("upgrade" in codeDeploymentRecord.mode) return "Upgrade";
      if ("install" in codeDeploymentRecord.mode) return "Install";
    };
    const moduleHash = getSHA256Hash(codeDeploymentRecord.module_hash);
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
            {wasmMetadata ? (
              <Box sx={{ marginTop: "8px" }}>
                <Button
                  onClick={() => {
                    onViewMetadata(wasmMetadata);
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
  if ("controllers_change" in change.details)
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
  if ("code_uninstall" in change.details) return "Code uninstall";
};

export default ActionCell;
