import {
  Box,
  Modal,
  ModalDialog,
  ModalClose,
  FormControl,
  FormLabel,
  Typography,
} from "@mui/joy";
import MDEditor from "@uiw/react-md-editor";

import { WasmMetadata } from "@declarations/cmm_be/cmm_be.did";
import { getSHA256Hash } from "@fe/utils/hash";

interface ViewWasmMetadataModalProps {
  wasmMetadata: WasmMetadata | null;
  isOpen: boolean;
  onClose: () => void;
}

const ViewWasmMetadataModal = ({
  wasmMetadata,
  isOpen,
  onClose,
}: ViewWasmMetadataModalProps) => {
  return (
    <Modal open={isOpen} onClose={onClose}>
      <ModalDialog sx={{ width: "calc(100% - 50px)", maxWidth: "700px" }}>
        <ModalClose />
        <Typography level="h4">View Wasm metadata</Typography>
        <Box sx={{ display: "flex", flexDirection: "column", gap: 2 }}>
          <FormControl>
            <FormLabel>Module hash</FormLabel>
            <Box>
              <Typography sx={{ wordBreak: "break-word" }}>
                {!!wasmMetadata && getSHA256Hash(wasmMetadata.module_hash)}
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
        </Box>
      </ModalDialog>
    </Modal>
  );
};

export default ViewWasmMetadataModal;
