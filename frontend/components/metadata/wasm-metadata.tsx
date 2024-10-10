import { useState } from "react";
import { Box, Table, IconButton, Tooltip } from "@mui/joy";
import { format } from "date-fns";
import VisibilityIcon from "@mui/icons-material/Visibility";
import EditIcon from "@mui/icons-material/Edit";

import { CanisterMetadataResponse } from "@declarations/history_be/history_be.did";
import { getSHA256Hash } from "@fe/utils/hash";
import ItemWithDetails from "@fe/components/item-with-details";
import { mapModuleHash } from "@fe/constants/knownHashes";

import ViewWasmMetadataModal from "./view-wasm-metadata";

interface WasmMetadataProps {
  data: CanisterMetadataResponse;
}

const WasmMetadata = ({ data }: WasmMetadataProps) => {
  console.log("=== data", data);
  const [viewModalIsOpen, setViewModalIsOpen] = useState(false);

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
              <td>
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
                        setViewModalIsOpen(true);
                      }}
                    >
                      <VisibilityIcon />
                    </IconButton>
                  </Tooltip>
                  <Tooltip title="Edit Wasm metadata">
                    <Box>
                      <IconButton>
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
        metadata={data}
        isOpen={viewModalIsOpen}
        onClose={() => {
          setViewModalIsOpen(false);
        }}
      />
    </Box>
  );
};

export default WasmMetadata;
