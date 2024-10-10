import {
  Box,
  Modal,
  ModalDialog,
  ModalClose,
  FormControl,
  FormLabel,
  Typography,
} from "@mui/joy";

import { CanisterMetadataResponse } from "@declarations/history_be/history_be.did";

interface ViewWasmMetadataModalProps {
  metadata: CanisterMetadataResponse;
  isOpen: boolean;
  onClose: () => void;
}

const ViewWasmMetadataModal = ({
  metadata,
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
            Here text
          </FormControl>
        </Box>
      </ModalDialog>
    </Modal>
  );
};

export default ViewWasmMetadataModal;
