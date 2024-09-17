import { useParams } from "react-router-dom";
import { Box, Divider, LinearProgress, Textarea } from "@mui/joy";
import { Principal } from "@dfinity/principal";
import { formatDistanceStrict } from "date-fns";
import { format, toZonedTime } from "date-fns-tz";

import DashboardPageLayout from "@fe/components/dashboard-page-layout";
import {
  MappedCanisterLogRecord,
  useCanisterStatus,
  useFetchCanisterLogs,
} from "@fe/integration";
import { canister_status_result } from "@fe/integration/management_idl/did";

interface ManageProps {
  callerIsController: boolean;
}

const Manage = ({ callerIsController }: ManageProps) => {
  const { canisterId } = useParams();

  const {
    data: canisterStatus,
    isFetching: isStatusFetching,
    refetch: statusRefetch,
  } = useCanisterStatus(Principal.fromText(canisterId!), callerIsController);

  const {
    data: logs,
    isFetching: isLogsFetching,
    refetch: logsRefetch,
  } = useFetchCanisterLogs(Principal.fromText(canisterId!), callerIsController);

  const mapStatus = (status: canister_status_result["status"]) => {
    if ("stopped" in status) return "Stopped";
    if ("stopping" in status) return "Stopping";
    if ("running" in status) return "Running";
  };

  const mapFreezingThreshold = (
    ft: canister_status_result["settings"]["freezing_threshold"]
  ) => {
    const seconds = formatDistanceStrict(0, Number(ft) * 1000, {
      unit: "second",
    });

    const days = formatDistanceStrict(0, Number(ft) * 1000, {
      unit: "day",
    });

    return `${seconds} (${days})`;
  };

  const createLogsText = (records: MappedCanisterLogRecord[]) => {
    return records.reduce((acc, record) => {
      const milliseconds = Number(record.timestamp_nanos / BigInt(1e6));
      const nanoseconds = record.timestamp_nanos % BigInt(1e9);
      const date = new Date(milliseconds);
      const zonedDate = toZonedTime(date, "Etc/UTC");
      const formattedDate = format(zonedDate, "yyyy-MM-dd'T'HH:mm:ss.SSS");
      const microsecondsPart = nanoseconds
        .toString()
        .padStart(9, "0")
        .slice(3, 6); // Only keep the microseconds part
      const dateLine = `${formattedDate}${microsecondsPart}Z`;
      const line = `[${record.idx}. ${dateLine}]: ${record.content}`;
      return acc + line + "\n";
    }, "");
  };

  return (
    <DashboardPageLayout
      title="Management"
      onRefetch={
        callerIsController
          ? () => {
              statusRefetch();
              logsRefetch();
            }
          : undefined
      }
      isFetching={isStatusFetching || isLogsFetching}
    >
      {!callerIsController ? (
        <Box>
          No access. Canister management is only available to controllers.
        </Box>
      ) : isStatusFetching || isLogsFetching ? (
        <LinearProgress sx={{ marginY: 1 }} />
      ) : !canisterStatus || !logs ? (
        "Something went wrong"
      ) : (
        <Box>
          <Box sx={{ marginBottom: 1 }}>
            <Box sx={{ display: "inline", fontWeight: 600 }}>Cycles:</Box>{" "}
            <Box sx={{ display: "inline" }}>
              {(Number(canisterStatus.cycles) / 1e12).toFixed(3)} TC (trillion
              cycles)
            </Box>
          </Box>
          <Box sx={{ marginBottom: 1 }}>
            <Box sx={{ display: "inline", fontWeight: 600 }}>Status:</Box>{" "}
            <Box sx={{ display: "inline" }}>
              {mapStatus(canisterStatus.status)}
            </Box>
          </Box>
          <Box sx={{ marginBottom: 2 }}>
            <Box sx={{ display: "inline", fontWeight: 600 }}>
              Freezing threshold:
            </Box>{" "}
            <Box sx={{ display: "inline" }}>
              {mapFreezingThreshold(canisterStatus.settings.freezing_threshold)}
            </Box>
          </Box>
          <Divider sx={{ marginBottom: 2 }} />
          <Box>
            <Box sx={{ fontWeight: 600, marginBottom: 1 }}>Logs</Box>
            <Textarea
              sx={{ width: "100%" }}
              minRows={5}
              maxRows={7}
              value={createLogsText(logs)}
            />
          </Box>
        </Box>
      )}
    </DashboardPageLayout>
  );
};

export default Manage;
