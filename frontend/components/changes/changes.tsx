import { useParams } from "react-router-dom";
import { parseISO, format } from "date-fns";
import { Principal } from "@dfinity/principal";
import { Box, LinearProgress, Table, useTheme } from "@mui/joy";

import DashboardPageLayout from "@fe/components/dashboard-page-layout";
import { useGetCanisterChanges } from "@fe/integration";

import HistorySummarySection from "./history-summary-section";
import HistoryInfoLine from "./history-info-line";
import GapsRowContent from "./gap-row-content";
import ActionCell from "./action-cell";
import OriginCell from "./origin-cell";
import { addGaps } from "./utils";

const Changes = () => {
  const theme = useTheme();

  const { canisterId } = useParams();

  const { data, isFetching, remove, refetch } = useGetCanisterChanges(
    Principal.fromText(canisterId!)
  );

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
            feature was officially launched on{" "}
            {format(parseISO("2023-06-05T09:47:46Z"), "MMM dd, yyyy HH:mm")}.
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
        remove();
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
                        <td>{<ActionCell change={change} />}</td>
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
    </DashboardPageLayout>
  );
};

export default Changes;
