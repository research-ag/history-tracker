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

import { PublicWasmMetadata } from "@declarations/history_be/history_be.did";

interface ViewWasmMetadataModalProps {
  wasmMetadata: PublicWasmMetadata | null;
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
      <ModalDialog sx={{ width: "calc(100% - 50px)", maxWidth: "450px" }}>
        <ModalClose />
        <Typography level="h4">View Wasm metadata</Typography>
        <Box>
          <FormControl>
            <FormLabel>Build instructions</FormLabel>
            {wasmMetadata?.build_instructions ? (
              <MDEditor.Markdown source={wasmMetadata.build_instructions} />
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
