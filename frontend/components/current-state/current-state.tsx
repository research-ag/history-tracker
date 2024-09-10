import { useParams } from "react-router-dom";
import { Principal } from "@dfinity/principal";
import { Box, LinearProgress } from "@mui/joy";

import { useReadState } from "@fe/integration";
import DashboardPageLayout from "@fe/components/dashboard-page-layout";
import { mapModuleHash } from "@fe/constants/knownHashes";

const CurrentState = () => {
  const { canisterId } = useParams();

  const { data, isFetching, remove, refetch } = useReadState(
    Principal.fromText(canisterId!)
  );

  return (
    <DashboardPageLayout
      title="State"
      onRefetch={() => {
        remove();
        refetch();
      }}
      isFetching={isFetching}
    >
      {isFetching ? (
        <LinearProgress sx={{ marginY: 1 }} />
      ) : !data ? (
        "Something went wrong"
      ) : (
        <Box>
          <Box sx={{ marginBottom: 1 }}>
            <Box sx={{ fontWeight: 600 }}>Module hash:</Box>{" "}
            <Box>{data.moduleHash}</Box>
          </Box>
          {mapModuleHash(data.moduleHash) && (
            <Box sx={{ marginBottom: 1 }}>
              <Box sx={{ fontWeight: 600 }}>Module hash is known as:</Box>{" "}
              <Box>{mapModuleHash(data.moduleHash)}</Box>
            </Box>
          )}
          <Box>
            <Box sx={{ fontWeight: 600 }}>Controllers:</Box>
            <Box component="ul">
              {data.controllers.map((controllerPrincipal, i) => (
                <Box key={i} component="li">
                  {controllerPrincipal}
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
