import { useState, useMemo, useEffect } from "react";
import { useParams } from "react-router-dom";
import { format } from "date-fns";
import { Principal } from "@dfinity/principal";
import {
  Alert,
  Box,
  LinearProgress,
  Select,
  Option,
  Table,
  useTheme,
  Typography,
} from "@mui/joy";

import DashboardPageLayout from "@fe/components/dashboard-page-layout";
import {
  useGetCanisterChanges,
  useGetWasmMetadataByPrincipal,
  usePrincipalsWithMetadata,
  useReadState,
} from "@fe/integration";
import { getSHA256Hash } from "@fe/utils/hash";
import { WasmMetadata } from "@declarations/cmm_be/cmm_be.did";
import { ExtendedChange } from "@declarations/history_be/history_be.did";

import ViewWasmMetadataModal from "../cmm/view-wasm-metadata";
import HistorySummarySection from "./history-summary-section";
import HistoryInfoLine from "./history-info-line";
import GapsRowContent from "./gap-row-content";
import ActionCell from "./action-cell";
import OriginCell from "./origin-cell";
import { addGaps } from "./utils";

const Changes = () => {
  const theme = useTheme();

  const { canisterId } = useParams();

  const { data, isFetching, refetch } = useGetCanisterChanges(
    Principal.fromText(canisterId!)
  );

  const [wasmMetadataToView, setWasmMetadataToView] =
    useState<WasmMetadata | null>(null);

  const [principalWithMetadata, setPrincipalWithMetadata] =
    useState<Principal | null>(null);

  const {
    data: { moduleHash: actualModuleHash, controllers } = {
      moduleHash: "",
      controllers: [],
    },
  } = useReadState(Principal.fromText(canisterId!), true);

  const { data: principalsWithMetadata } = usePrincipalsWithMetadata({
    principals: controllers.map((c) => Principal.fromText(c)),
  });

  const { data: wasmMetadata = [] } = useGetWasmMetadataByPrincipal(
    {
      principal: principalWithMetadata!,
    },
    !!principalWithMetadata
  );

  const wasmMetadataMap = useMemo(
    () =>
      wasmMetadata.reduce<Record<string, WasmMetadata>>(
        (acc, item: WasmMetadata) => ({
          ...acc,
          [getSHA256Hash(item.module_hash)]: item,
        }),
        {}
      ),
    [wasmMetadata]
  );

  const getWasmMetadata = (change: ExtendedChange): WasmMetadata | null => {
    if ("code_deployment" in change.details) {
      const codeDeploymentRecord = change.details.code_deployment;
      const moduleHash = getSHA256Hash(codeDeploymentRecord.module_hash);
      return wasmMetadataMap[moduleHash] ?? null;
    }
    return null;
  };

  useEffect(() => {
    setPrincipalWithMetadata(
      principalsWithMetadata?.length ? principalsWithMetadata[0] : null
    );
  }, [principalsWithMetadata]);

  const cmmList = principalsWithMetadata ?? [];

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
      rightPart={
        <>
          {cmmList.length ? (
            <Select
              sx={{ maxWidth: "200px", mb: 1 }}
              slotProps={{
                listbox: {
                  sx: {
                    "& li": {
                      maxWidth: "200px",
                    },
                  },
                },
              }}
              size="sm"
              value={
                principalWithMetadata ? principalWithMetadata.toText() : null
              }
              onChange={(_, value) => {
                setPrincipalWithMetadata(Principal.fromText(value as string));
              }}
            >
              {cmmList.map((p) => (
                <Option key={p.toText()} value={p.toText()}>
                  {p.toText()}
                </Option>
              ))}
            </Select>
          ) : (
            <Typography level="body-sm">Metadata not found</Typography>
          )}
          <HistorySummarySection changes={data?.changes} />
        </>
      }
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
                              wasmMetadata={getWasmMetadata(change)}
                              onViewMetadata={setWasmMetadataToView}
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
      <ViewWasmMetadataModal
        wasmMetadata={wasmMetadataToView}
        isOpen={!!wasmMetadataToView}
        onClose={() => setWasmMetadataToView(null)}
      />
    </DashboardPageLayout>
  );
};

export default Changes;
