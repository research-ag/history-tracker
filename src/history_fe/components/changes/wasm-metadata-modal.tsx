import {
  Modal,
  ModalDialog,
  ModalClose,
  Typography,
  Select,
  Option,
} from "@mui/joy";
import { Principal } from "@dfinity/principal";

import WasmMetadataView from "@fe/components/wasm-metadata-view";
import { useEffect, useState } from "react";
import { useFindWasmMetadata } from "@fe/integration";

interface WasmMetadataModalProps {
  moduleHash: Uint8Array | number[] | null;
  metadataMap: Record<string, Array<Principal>>;
  isOpen: boolean;
  onClose: () => void;
}

const WasmMetadataModal = ({
  moduleHash,
  isOpen,
  onClose,
  metadataMap,
}: WasmMetadataModalProps) => {
  const principalsWithMetadata = moduleHash
    ? metadataMap[moduleHash.join(",")]
    : [];

  const [selectedPrincipal, setSelectedPrincipal] = useState<Principal | null>(
    null
  );

  const { data: wasmMetadata = null } = useFindWasmMetadata(
    {
      principal: selectedPrincipal!,
      moduleHash: moduleHash!,
    },
    !!selectedPrincipal && !!moduleHash
  );

  useEffect(() => {
    if (moduleHash) {
      setSelectedPrincipal(principalsWithMetadata[0] ?? null);
    }
  }, [moduleHash]);

  useEffect(() => {
    if (!isOpen) {
      setSelectedPrincipal(null);
    }
  }, [isOpen]);

  return (
    <Modal open={isOpen} onClose={onClose}>
      <ModalDialog sx={{ width: "calc(100% - 50px)", maxWidth: "700px" }}>
        <ModalClose />
        <Typography level="h4">View Wasm metadata</Typography>
        <Select
          value={selectedPrincipal}
          onChange={(_, p) => setSelectedPrincipal(p)}
        >
          {principalsWithMetadata.map((p) => (
            <Option key={p.toText()} value={p}>
              {p.toText()}
            </Option>
          ))}
        </Select>
        <WasmMetadataView wasmMetadata={wasmMetadata} />
      </ModalDialog>
    </Modal>
  );
};

export default WasmMetadataModal;
