import { useState } from "react";
import {
  Box,
  Button,
  Typography,
  Table,
  IconButton,
  Tooltip,
  useTheme,
} from "@mui/joy";
import { format } from "date-fns";
import VisibilityIcon from "@mui/icons-material/Visibility";
import EditIcon from "@mui/icons-material/Edit";
import { useMediaQuery } from "@mui/material"; // TODO: @mui/material should not be used. Temporary solution.

import { useGetWasmMetadata } from "@fe/integration";
import { getSHA256Hash } from "@fe/utils/hash";
import { mapModuleHash } from "@fe/constants/knownHashes";
import ItemWithDetails from "@fe/components/item-with-details";
import { WasmMetadata } from "@bindings/metadata_directory";

import WasmMetadataModal from "./wasm-metadata-modal";
import ViewWasmMetadataModal from "./view-wasm-metadata";

const WasmMetadata_ = () => {
  const theme = useTheme();

  const downMd = useMediaQuery(theme.breakpoints.down("md"));
  const downSm = useMediaQuery(theme.breakpoints.down("sm"));

  const [modalIsOpen, setModalIsOpen] = useState(false);
  const [wasmMetadataToEdit, setWasmMetadataToEdit] =
    useState<WasmMetadata | null>(null);

  const [wasmMetadataToView, setWasmMetadataToView] =
    useState<WasmMetadata | null>(null);

  const { data } = useGetWasmMetadata();

  const renderModuleHash = (record: WasmMetadata) => {
    return (
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
    );
  };

  const renderActions = (record: WasmMetadata) => {
    return (
      <Box
        sx={{
          display: "flex",
          alignItems: "center",
          gap: "8px",
        }}
      >
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
    );
  };

  return (
    <Box>
      <Box
        sx={(theme) => ({
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",

          [theme.breakpoints.down("md")]: {
            marginBottom: 2,
          },

          [theme.breakpoints.down("sm")]: {
            flexDirection: "column",
            alignItems: "start",
            rowGap: 1,
          },
        })}
      >
        <Typography level={!downSm ? "h2" : "h4"}>Wasm metadata</Typography>
        <Button
          sx={(theme) => ({
            [theme.breakpoints.down("sm")]: {
              width: "100%",
            },
          })}
          onClick={() => {
            setModalIsOpen(true);
            setWasmMetadataToEdit(null);
          }}
        >
          New Wasm module
        </Button>
      </Box>
      {!downMd && (
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
            {[...(data ?? [])]
              .sort(
                (a, b) =>
                  Number(a.created_timestamp) - Number(b.created_timestamp)
              )
              .map((record, i) => (
                <tr key={record.module_hash.join(";")}>
                  <td>{i + 1}</td>
                  <td>
                    {format(
                      new Date(
                        Number(record.latest_update_timestamp) / 1_000_000
                      ),
                      "MMM dd, yyyy HH:mm"
                    )}
                  </td>
                  <td>{renderModuleHash(record)}</td>
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
                  <td>{renderActions(record)}</td>
                </tr>
              ))}
          </tbody>
        </Table>
      )}
      {downMd && (
        <Box sx={{ display: "flex", flexDirection: "column", gap: 1 }}>
          {[...(data ?? [])]
            .sort(
              (a, b) =>
                Number(a.created_timestamp) - Number(b.created_timestamp)
            )
            .map((record, i) => (
              <Box
                sx={(theme) => ({
                  backgroundColor: theme.palette.background.level1,
                  borderRadius: "8px",
                })}
                key={record.module_hash.join(";")}
              >
                <Table
                  sx={{
                    "& tr": { height: "45px" },
                    "& td:first-child": {
                      fontWeight: 600,
                    },
                  }}
                >
                  <colgroup>
                    <col style={{ width: "140px" }} />
                    <col />
                  </colgroup>
                  <tbody>
                    <tr>
                      <td>N</td>
                      <td>{i + 1}</td>
                    </tr>
                    <tr>
                      <td>Updated at</td>
                      <td>
                        {format(
                          new Date(
                            Number(record.latest_update_timestamp) / 1_000_000
                          ),
                          "MMM dd, yyyy HH:mm"
                        )}
                      </td>
                    </tr>
                    <tr>
                      <td>Module hash</td>
                      <td>{renderModuleHash(record)}</td>
                    </tr>
                    <tr>
                      <td>Description</td>
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
                    </tr>
                    <tr>
                      <td>Build instructions</td>
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
                    </tr>
                    <tr>
                      <td>Actions</td>
                      <td>{renderActions(record)}</td>
                    </tr>
                  </tbody>
                </Table>
              </Box>
            ))}
        </Box>
      )}
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
