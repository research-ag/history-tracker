import { Modal, ModalDialog, ModalClose, Typography } from "@mui/joy";

import { WasmMetadata } from "@bindings/metadata_directory";
import WasmMetadataView from "@fe/components/wasm-metadata-view";

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
        <WasmMetadataView wasmMetadata={wasmMetadata} />
      </ModalDialog>
    </Modal>
  );
};

export default ViewWasmMetadataModal;
