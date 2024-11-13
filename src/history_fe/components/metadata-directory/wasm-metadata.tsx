import { useState } from "react";
import { Box, Button, Typography, Table, IconButton, Tooltip } from "@mui/joy";
import { format } from "date-fns";
import VisibilityIcon from "@mui/icons-material/Visibility";
import EditIcon from "@mui/icons-material/Edit";

import { useGetWasmMetadata } from "@fe/integration";
import { getSHA256Hash } from "@fe/utils/hash";
import { mapModuleHash } from "@fe/constants/knownHashes";
import ItemWithDetails from "@fe/components/item-with-details";
import { WasmMetadata } from "@declarations/metadata_directory/metadata_directory.did";

import WasmMetadataModal from "./wasm-metadata-modal";
import ViewWasmMetadataModal from "./view-wasm-metadata";

const WasmMetadata_ = () => {
  const [modalIsOpen, setModalIsOpen] = useState(false);
  const [wasmMetadataToEdit, setWasmMetadataToEdit] =
    useState<WasmMetadata | null>(null);

  const [wasmMetadataToView, setWasmMetadataToView] =
    useState<WasmMetadata | null>(null);

  const { data } = useGetWasmMetadata();

  return (
    <Box>
      <Box
        sx={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
        }}
      >
        <Typography level="h2">Wasm metadata</Typography>
        <Button
          onClick={() => {
            setModalIsOpen(true);
            setWasmMetadataToEdit(null);
          }}
        >
          New Wasm module
        </Button>
      </Box>
      <Table sx={{ "& tr": { height: "45px" } }}>
        <colgroup>
          <col style={{ width: "40px" }} />
          <col style={{ width: "160px" }} />
          <col style={{ width: "200px" }} />
          <col />
          <col />
          <col style={{ width: "100px" }} />
        </colgroup>
        <thead>
          <tr>
            <th>N</th>
            <th>Updated at</th>
            <th>Module hash</th>
            <th>Description</th>
            <th>Build instructions</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {(data ?? []).map((record, i) => (
            <tr key={record.module_hash.join(";")}>
              <td>{i + 1}</td>
              <td>
                {format(
                  new Date(Number(record.latest_update_timestamp) / 1_000_000),
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
                {record.description ? (
                  record.description
                ) : (
                  <Box sx={{ opacity: 0.4 }}>Empty</Box>
                )}
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
                  <Tooltip title="Edit Wasm metadata">
                    <Box>
                      <IconButton
                        onClick={() => {
                          setModalIsOpen(true);
                          setWasmMetadataToEdit(record);
                        }}
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
      <WasmMetadataModal
        wasmMetadata={wasmMetadataToEdit}
        isOpen={modalIsOpen}
        onClose={() => {
          setModalIsOpen(false);
          setWasmMetadataToEdit(null);
        }}
      />
    </Box>
  );
};

export default WasmMetadata_;
