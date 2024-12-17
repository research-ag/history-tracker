import { useParams } from "react-router-dom";
import { Principal } from "@dfinity/principal";
import { Box, LinearProgress } from "@mui/joy";

import {
  useAssetsRootHash,
  useAssetsFrozen,
  useReadState,
} from "@fe/integration";
import DashboardPageLayout from "@fe/components/dashboard-page-layout";
import { mapModuleHash } from "@fe/constants/knownHashes";

const CurrentState = () => {
  const { canisterId } = useParams();

  const { data, isFetching, refetch } = useReadState(
    Principal.fromText(canisterId!),
    true
  );

  const moduleHashName = mapModuleHash(data?.moduleHash ?? "");

  const {
    data: assetsRootHash,
    isFetching: isAssetsRootHashFetching,
    refetch: refetchAssetsRootHash,
  } = useAssetsRootHash(
    Principal.fromText(canisterId!),
    moduleHashName.includes("asset")
  );

  const {
    data: assetsFrozen,
    isFetching: isAssetsFrozenFetching,
    refetch: refetchAssetsFrozen,
  } = useAssetsFrozen(
    Principal.fromText(canisterId!),
    moduleHashName.includes("asset")
  );

  return (
    <DashboardPageLayout
      title="State"
      onRefetch={() => {
        refetch();
        refetchAssetsRootHash();
        refetchAssetsFrozen();
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
          {moduleHashName && (
            <Box sx={{ marginBottom: 1 }}>
              <Box sx={{ fontWeight: 600 }}>Module hash is known as:</Box>{" "}
              <Box>{moduleHashName}</Box>
            </Box>
          )}
          {moduleHashName.includes("asset") && (
            <>
              <Box sx={{ marginBottom: 1 }}>
                <Box sx={{ fontWeight: 600 }}>Assets root hash:</Box>{" "}
                <Box>
                  {assetsRootHash
                    ? assetsRootHash.rootHash
                    : isAssetsRootHashFetching
                    ? "Loading..."
                    : "ERROR"}
                </Box>
              </Box>
              <Box sx={{ marginBottom: 1 }}>
                <Box sx={{ display: "inline", fontWeight: 600 }}>
                  Assets are frozen:
                </Box>{" "}
                <Box sx={{ display: "inline" }}>
                  {assetsFrozen
                    ? String(assetsFrozen.isFrozen)
                    : isAssetsFrozenFetching
                    ? "Loading..."
                    : "ERROR"}
                </Box>
              </Box>
            </>
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
