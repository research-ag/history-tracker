import { useState, useMemo } from "react";
import { useParams } from "react-router-dom";
import { format } from "date-fns";
import { Principal } from "@dfinity/principal";
import { Alert, Box, LinearProgress, Table, useTheme } from "@mui/joy";

import DashboardPageLayout from "@fe/components/dashboard-page-layout";
import {
  useGetCanisterChanges,
  useAvailableMetadata,
  useReadState,
} from "@fe/integration";
import { getSHA256Hash } from "@fe/utils/hash";
import { useMetadataSources } from "@fe/utils/metadata-sources";
import { extractModuleHashes } from "@fe/utils/extract-module-hashes";

import HistorySummarySection from "./history-summary-section";
import HistoryInfoLine from "./history-info-line";
import GapsRowContent from "./gap-row-content";
import ActionCell from "./action-cell";
import OriginCell from "./origin-cell";
import WasmMetadataModal from "./wasm-metadata-modal";
import { addGaps } from "./utils";

const Changes = () => {
  const theme = useTheme();

  const { canisterId } = useParams();

  const { data, isFetching, refetch } = useGetCanisterChanges(
    Principal.fromText(canisterId!)
  );

  const [moduleHashToViewMetadata, setModuleHashToViewMetadata] = useState<
    (Uint8Array | number[]) | null
  >(null);

  const {
    data: { moduleHash: actualModuleHash } = {
      moduleHash: "",
      controllers: [],
    },
  } = useReadState(Principal.fromText(canisterId!), true);

  const { metadataSources } = useMetadataSources();

  const moduleHashes = useMemo(
    () => extractModuleHashes(data?.changes ?? []),
    [data]
  );

  const { data: availableMetadata } = useAvailableMetadata({
    principals: metadataSources,
    moduleHashes,
  });

  const metadataMap = useMemo<Record<string, Array<Principal>>>(() => {
    return (availableMetadata ?? []).reduce<Record<string, Array<Principal>>>(
      (acc, [p, moduleHash]) => ({
        ...acc,
        [moduleHash.join(",")]: [...(acc[moduleHash.join(",")] ?? []), p],
      }),
      {}
    );
  }, [availableMetadata]);

  const showWarning = useMemo(() => {
    if (!data || !actualModuleHash) {
      return false;
    }

    for (const change of [...data.changes].reverse()) {
      if ("code_deployment" in change.details) {
        const { module_hash } = change.details.code_deployment;
        return getSHA256Hash(module_hash) !== actualModuleHash;
      }
    }

    return false;
  }, [data, actualModuleHash]);

  return (
    <DashboardPageLayout
      title="Changelog"
      rightPart={<HistorySummarySection changes={data?.changes} />}
      noteTooltip={
        <Box sx={{ width: "400px" }}>
          <Box sx={{ marginBottom: 1 }}>
            Please be aware that the history of a canister on the Internet
            Computer can only be recorded and accessed from the moment the
            feature enabling canister history tracking was released. This
            feature was officially launched on 2023-06-05, 9:47:46 AM UTC.
          </Box>
          <Box>
            Any actions or events involving canisters prior to this date will
            not be included in the historical records. We appreciate your
            understanding and encourage you to take this into consideration when
            reviewing canister activities and logs.
          </Box>
        </Box>
      }
      onRefetch={() => {
        refetch();
      }}
      isFetching={isFetching}
    >
      <Box sx={{ width: "100%", overflow: "auto" }}>
        {isFetching ? (
          <LinearProgress sx={{ marginY: 1 }} />
        ) : !data ? (
          "Something went wrong"
        ) : (
          <>
            {showWarning && (
              <Box sx={{ marginBottom: 1 }}>
                <Alert color="warning" size="sm">
                  The actual module hash is different from that found in the
                  latest sync. Probably the changelog is awaiting an update.
                </Alert>
              </Box>
            )}
            <HistoryInfoLine data={data} />
            <Table sx={{ "& tr": { height: "45px" } }}>
              <colgroup>
                <col style={{ width: "80px" }} />
                <col style={{ width: "100px" }} />
                <col />
                <col />
                <col style={{ width: "180px" }} />
              </colgroup>

              <thead>
                <tr>
                  <th>Index</th>
                  <th>Version</th>
                  <th>Action</th>
                  <th>Origin</th>
                  <th>Date</th>
                </tr>
              </thead>
              <tbody>
                {addGaps(data.changes)
                  .reverse()
                  .map((change, i) => {
                    if (typeof change == "number") {
                      return (
                        <tr
                          style={{ background: theme.palette.warning[50] }}
                          key={i}
                        >
                          <td colSpan={5}>
                            <GapsRowContent gaps={change} />
                          </td>
                        </tr>
                      );
                    }

                    return (
                      <tr key={change.timestamp_nanos}>
                        <td>{Number(change.change_index)}</td>
                        <td>{Number(change.canister_version)}</td>
                        <td>
                          {
                            <ActionCell
                              change={change}
                              metadataMap={metadataMap}
                              onViewMetadata={setModuleHashToViewMetadata}
                            />
                          }
                        </td>
                        <td>{<OriginCell change={change} />}</td>
                        <td>
                          {format(
                            new Date(
                              Number(change.timestamp_nanos) / 1_000_000
                            ),
                            "MMM dd, yyyy HH:mm"
                          )}
                        </td>
                      </tr>
                    );
                  })}
              </tbody>
            </Table>
          </>
        )}
      </Box>
      <WasmMetadataModal
        moduleHash={moduleHashToViewMetadata}
        metadataMap={metadataMap}
        isOpen={!!moduleHashToViewMetadata}
        onClose={() => {
          setModuleHashToViewMetadata(null);
        }}
      />
    </DashboardPageLayout>
  );
};

export default Changes;
