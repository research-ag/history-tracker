import { useParams } from "react-router-dom";
import { Box, LinearProgress } from "@mui/joy";
import { Principal } from "@dfinity/principal";
import { formatDistanceStrict } from "date-fns";

import DashboardPageLayout from "@fe/components/dashboard-page-layout";
import { useCanisterStatus } from "@fe/integration";
import { canister_status_result } from "@fe/integration/management_idl/did";

interface ManageProps {
  callerIsController: boolean;
}

const Manage = ({ callerIsController }: ManageProps) => {
  const { canisterId } = useParams();

  const { data, isFetching, remove, refetch } = useCanisterStatus(
    Principal.fromText(canisterId!),
    callerIsController
  );

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

  return (
    <DashboardPageLayout
      title="Management"
      onRefetch={
        callerIsController
          ? () => {
              remove();
              refetch();
            }
          : undefined
      }
      isFetching={isFetching}
    >
      {!callerIsController ? (
        <Box>
          No access. Canister management is only available to controllers.
        </Box>
      ) : isFetching ? (
        <LinearProgress sx={{ marginY: 1 }} />
      ) : !data ? (
        "Something went wrong"
      ) : (
        <Box>
          <Box sx={{ marginBottom: 1 }}>
            <Box sx={{ display: "inline", fontWeight: 600 }}>Cycles:</Box>{" "}
            <Box sx={{ display: "inline" }}>
              {(Number(data.cycles) / 1e12).toFixed(3)} TC (trillion cycles)
            </Box>
          </Box>
          <Box sx={{ marginBottom: 1 }}>
            <Box sx={{ display: "inline", fontWeight: 600 }}>Status:</Box>{" "}
            <Box sx={{ display: "inline" }}>{mapStatus(data.status)}</Box>
          </Box>
          <Box>
            <Box sx={{ display: "inline", fontWeight: 600 }}>
              Freezing threshold:
            </Box>{" "}
            <Box sx={{ display: "inline" }}>
              {mapFreezingThreshold(data.settings.freezing_threshold)}
            </Box>
          </Box>
        </Box>
      )}
    </DashboardPageLayout>
  );
};

export default Manage;
