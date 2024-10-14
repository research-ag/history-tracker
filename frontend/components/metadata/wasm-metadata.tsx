import { useState } from "react";
import { Box, Table, IconButton, Tooltip } from "@mui/joy";
import { format } from "date-fns";
import { Principal } from "@dfinity/principal";
import VisibilityIcon from "@mui/icons-material/Visibility";
import EditIcon from "@mui/icons-material/Edit";

import {
  CanisterMetadataResponse,
  PublicWasmMetadata,
} from "@declarations/history_be/history_be.did";
import { getSHA256Hash } from "@fe/utils/hash";
import ItemWithDetails from "@fe/components/item-with-details";
import { mapModuleHash } from "@fe/constants/knownHashes";

import ViewWasmMetadataModal from "./view-wasm-metadata";
import UpdateWasmMetadataModal from "./update-wasm-metadata-modal";

interface WasmMetadataProps {
  canisterId: Principal;
  data: CanisterMetadataResponse;
  callerIsController: boolean;
}

const WasmMetadata = ({
  canisterId,
  data,
  callerIsController,
}: WasmMetadataProps) => {
  const [wasmMetadataToView, setWasmMetadataToView] =
    useState<PublicWasmMetadata | null>(null);

  const [wasmMetadataToEdit, setWasmMetadataToEdit] =
    useState<PublicWasmMetadata | null>(null);

  return (
    <Box>
      <Table sx={{ "& tr": { height: "45px" } }}>
        <colgroup>
          <col style={{ width: "40px" }} />
          <col style={{ width: "160px" }} />
          <col style={{ width: "160px" }} />
          <col />
          <col style={{ width: "100px" }} />
        </colgroup>
        <thead>
          <tr>
            <th>N</th>
            <th>Found at</th>
            <th>Module hash</th>
            <th>Build instructions</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {data.module_hash_metadata.map((record, i) => (
            <tr key={String(record.first_found_timestamp)}>
              <td>{i + 1}</td>
              <td>
                {format(
                  new Date(Number(record.first_found_timestamp) / 1_000_000),
                  "MMM dd, yyyy HH:mm"
                )}
              </td>
              <td>
                {
                  <ItemWithDetails
                    title={getSHA256Hash(record.module_hash).slice(0, 7)}
                    hash={getSHA256Hash(record.module_hash)}
                    titleIsHash
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
                          {getSHA256Hash(record.module_hash)}
                        </Box>
                        {mapModuleHash(getSHA256Hash(record.module_hash)) && (
                          <Box>
                            <Box
                              sx={{
                                display: "inline",
                                fontWeight: 600,
                              }}
                            >
                              Module hash is known:
                            </Box>{" "}
                            {mapModuleHash(getSHA256Hash(record.module_hash))}
                          </Box>
                        )}
                      </Box>
                    }
                  />
                }
              </td>
              <td
                style={{
                  whiteSpace: "nowrap",
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                }}
              >
                {record.build_instructions ? (
                  record.build_instructions
                ) : (
                  <Box sx={{ opacity: 0.4 }}>Empty</Box>
                )}
              </td>
              <td>
                <Box sx={{ display: "flex", alignItems: "center", gap: "8px" }}>
                  <Tooltip title="View Wasm metadata">
                    <IconButton
                      onClick={() => {
                        setWasmMetadataToView(record);
                      }}
                    >
                      <VisibilityIcon />
                    </IconButton>
                  </Tooltip>
                  <Tooltip
                    title={
                      callerIsController
                        ? "Edit Wasm metadata"
                        : "You have to be a controller for editing"
                    }
                  >
                    <Box>
                      <IconButton
                        onClick={() => {
                          setWasmMetadataToEdit(record);
                        }}
                        disabled={!callerIsController}
                      >
                        <EditIcon />
                      </IconButton>
                    </Box>
                  </Tooltip>
                </Box>
              </td>
            </tr>
          ))}
        </tbody>
      </Table>
      <ViewWasmMetadataModal
        wasmMetadata={wasmMetadataToView}
        isOpen={!!wasmMetadataToView}
        onClose={() => {
          setWasmMetadataToView(null);
        }}
      />
      <UpdateWasmMetadataModal
        canisterId={canisterId}
        wasmMetadata={wasmMetadataToEdit}
        isOpen={!!wasmMetadataToEdit}
        onClose={() => {
          setWasmMetadataToEdit(null);
        }}
      />
    </Box>
  );
};

export default WasmMetadata;
