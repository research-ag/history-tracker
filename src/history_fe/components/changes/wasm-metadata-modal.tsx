import {
  Modal,
  ModalDialog,
  ModalClose,
  Typography,
  Select,
  Option,
  ListSubheader,
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
  metadataSources: {
    customSources: Array<Principal>;
    activeControllers: Array<Principal>;
    historyControllers: Array<Principal>;
  };
}

const WasmMetadataModal = ({
  moduleHash,
  metadataMap,
  isOpen,
  onClose,
  metadataSources,
}: WasmMetadataModalProps) => {
  const principalsWithMetadata = moduleHash
    ? metadataMap[moduleHash.join(",")]
    : [];

  const [selectedPrincipalText, setSelectedPrincipalText] = useState<
    string | null
  >(null);

  const selectedPrincipal = selectedPrincipalText
    ? Principal.fromText(selectedPrincipalText.split("_")[1])
    : null;

  const { data: wasmMetadata = null } = useFindWasmMetadata(
    {
      principal: selectedPrincipal!,
      moduleHash: moduleHash!,
    },
    !!selectedPrincipal && !!moduleHash
  );

  const principalsMap = principalsWithMetadata.reduce<Record<string, true>>(
    (acc, p) => ({
      ...acc,
      [p.toText()]: true,
    }),
    {}
  );

  const filterPrincipals = (principals: Array<Principal>) =>
    principals.filter((p) => principalsMap[p.toText()]);

  const metadataGroups = {
    customSources: filterPrincipals(metadataSources.customSources),
    activeControllers: filterPrincipals(metadataSources.activeControllers),
    historyControllers: filterPrincipals(metadataSources.historyControllers),
  };

  useEffect(() => {
    // Preselect principal
    if (moduleHash && principalsWithMetadata[0]) {
      for (const key of [
        "customSources",
        "activeControllers",
        "historyControllers",
      ] as (keyof typeof metadataGroups)[]) {
        if (metadataGroups[key][0]) {
          setSelectedPrincipalText(`${key}_${metadataGroups[key][0].toText()}`);
          break;
        }
      }
    }
  }, [moduleHash]);

  useEffect(() => {
    if (!isOpen) {
      setSelectedPrincipalText(null);
    }
  }, [isOpen]);

  return (
    <Modal open={isOpen} onClose={onClose}>
      <ModalDialog sx={{ width: "calc(100% - 50px)", maxWidth: "700px" }}>
        <ModalClose />
        <Typography level="h4">View Wasm metadata</Typography>
        <Select
          value={selectedPrincipalText}
          onChange={(_, value) => setSelectedPrincipalText(value)}
        >
          <ListSubheader>
            Custom sources ({metadataGroups.customSources.length})
          </ListSubheader>
          {metadataGroups.customSources.map((p) => (
            <Option
              key={`customSources_${p.toText()}`}
              value={`customSources_${p.toText()}`}
            >
              {p.toText()}
            </Option>
          ))}
          <ListSubheader>
            Active controllers ({metadataGroups.activeControllers.length})
          </ListSubheader>
          {metadataGroups.activeControllers.map((p) => (
            <Option
              key={`activeControllers_${p.toText()}`}
              value={`activeControllers_${p.toText()}`}
            >
              {p.toText()}
            </Option>
          ))}
          <ListSubheader>
            History controllers ({metadataGroups.historyControllers.length})
          </ListSubheader>
          {metadataGroups.historyControllers.map((p) => (
            <Option
              key={`historyControllers_${p.toText()}`}
              value={`historyControllers_${p.toText()}`}
            >
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
