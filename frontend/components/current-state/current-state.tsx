import { useParams } from "react-router-dom";
import { format } from "date-fns";
import { Principal } from "@dfinity/principal";
import { SHA256, enc } from "crypto-js";
import { Box, LinearProgress, Typography } from "@mui/joy";

import { useGetCanisterState } from "@fe/integration";
import DashboardPageLayout from "@fe/components/dashboard-page-layout";
import { CanisterStateResponse } from "@declarations/history_be/history_be.did";

const CurrentState = () => {
  const { canisterId } = useParams();

  const { data, isLoading } = useGetCanisterState(
    Principal.fromText(canisterId!)
  );

  const getModuleHash = (data: CanisterStateResponse) => {
    const hash = SHA256(data.module_hash.join(","));
    return hash.toString(enc.Hex);
  };

  return (
    <DashboardPageLayout title="State">
      {isLoading ? (
        <LinearProgress sx={{ marginY: 1 }} />
      ) : !data ? (
        "Something went wrong"
      ) : (
        <Box>
          <Typography sx={{ marginBottom: 1 }} level="body-sm">
            Latest sync:{" "}
            {data.timestamp_nanos > 0
              ? format(
                  new Date(Number(data.timestamp_nanos) / 1_000_000),
                  "MMM dd, yyyy HH:mm"
                )
              : "N/A"}
          </Typography>
          <Box sx={{ marginBottom: 1 }}>
            <Box sx={{ fontWeight: 600 }}>Module hash:</Box>{" "}
            {getModuleHash(data)}
          </Box>
          <Box>
            <Box sx={{ fontWeight: 600 }}>Controllers:</Box>
            <Box component="ul">
              {data.controllers.map((c, i) => (
                <Box key={i} component="li">
                  {c.toText()}
                </Box>
              ))}
            </Box>
          </Box>
        </Box>
      )}
    </DashboardPageLayout>
  );
};

export default CurrentState;
