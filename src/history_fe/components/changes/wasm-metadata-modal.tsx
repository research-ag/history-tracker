import { useEffect, useMemo, useState } from "react";
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

import { WasmMetadata } from "@declarations/metadata_directory/metadata_directory.did";
import WasmMetadataView from "@fe/components/wasm-metadata-view";
import { useFindWasmMetadata } from "@fe/integration";

interface WasmMetadataModalProps {
  moduleHash: Uint8Array | number[] | null;
  metadataMap: Record<string, Array<Principal>>;
  isOpen: boolean;
  onClose: () => void;
  metadataSources: {
    customSources: Array<Principal>;
    currentControllers: Array<Principal>;
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

  const { data: foundWasmMetadata = [] } = useFindWasmMetadata(
    {
      principals: principalsWithMetadata,
      moduleHash: moduleHash!,
    },
    !!moduleHash
  );

  const wasmMetadataMap = useMemo(
    () =>
      foundWasmMetadata.reduce<Record<string, WasmMetadata>>(
        (acc, [p, wasmMetadata]) => ({
          ...acc,
          [p.toText()]: wasmMetadata,
        }),
        {}
      ),
    [foundWasmMetadata]
  );

  const wasmMetadata = selectedPrincipalText
    ? wasmMetadataMap[selectedPrincipalText.split("_")[1]] ?? null
    : null;

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
    currentControllers: filterPrincipals(metadataSources.currentControllers),
    historyControllers: filterPrincipals(metadataSources.historyControllers),
  };

  useEffect(() => {
    // Preselect principal
    if (moduleHash && principalsWithMetadata[0]) {
      for (const key of [
        "customSources",
        "currentControllers",
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
            Current controllers ({metadataGroups.currentControllers.length})
          </ListSubheader>
          {metadataGroups.currentControllers.map((p) => (
            <Option
              key={`currentControllers_${p.toText()}`}
              value={`currentControllers_${p.toText()}`}
            >
              {p.toText()}
            </Option>
          ))}
          <ListSubheader>
            All controllers from known history (
            {metadataGroups.historyControllers.length})
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
