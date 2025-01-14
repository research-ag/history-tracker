import { Box, FormControl, FormLabel, Typography } from "@mui/joy";
import MDEditor from "@uiw/react-md-editor";
import { format } from "date-fns";

import { WasmMetadata } from "@declarations/metadata_directory/metadata_directory.did";
import { getSHA256Hash } from "@fe/utils/hash";

interface WasmMetadataViewProps {
  wasmMetadata: WasmMetadata | null;
}

const WasmMetadataView = ({ wasmMetadata }: WasmMetadataViewProps) => {
  return (
    <Box sx={{ display: "flex", flexDirection: "column", gap: 2 }}>
      <FormControl>
        <FormLabel>Module hash</FormLabel>
        <Box>
          <Typography sx={{ wordBreak: "break-word" }}>
            {wasmMetadata ? getSHA256Hash(wasmMetadata.module_hash) : "N/A"}
          </Typography>
        </Box>
      </FormControl>
      <FormControl>
        <FormLabel>Description</FormLabel>
        {wasmMetadata?.description ? (
          <Box>
            <Typography>{wasmMetadata.description}</Typography>
          </Box>
        ) : (
          <Box sx={{ opacity: 0.4 }}>Empty</Box>
        )}
      </FormControl>
      <FormControl>
        <FormLabel>Build instructions</FormLabel>
        {wasmMetadata?.build_instructions ? (
          <Box
            sx={{
              border: (theme) =>
                `1px solid ${theme.palette.primary.outlinedBorder}`,
            }}
          >
            <MDEditor.Markdown
              style={{ padding: "8px" }}
              source={wasmMetadata.build_instructions}
            />
          </Box>
        ) : (
          <Box sx={{ opacity: 0.4 }}>Empty</Box>
        )}
      </FormControl>
      <FormControl>
        <FormLabel>Created at</FormLabel>
        <Box>
          <Typography>
            {wasmMetadata
              ? format(
                  new Date(Number(wasmMetadata.created_timestamp) / 1_000_000),
                  "MMM dd, yyyy HH:mm"
                )
              : "N/A"}
          </Typography>
        </Box>
      </FormControl>
      <FormControl>
        <FormLabel>Updated at</FormLabel>
        <Box>
          <Typography>
            {wasmMetadata
              ? format(
                  new Date(
                    Number(wasmMetadata.latest_update_timestamp) / 1_000_000
                  ),
                  "MMM dd, yyyy HH:mm"
                )
              : "N/A"}
          </Typography>
        </Box>
      </FormControl>
    </Box>
  );
};

export default WasmMetadataView;
