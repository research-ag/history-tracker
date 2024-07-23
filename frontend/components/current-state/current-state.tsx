import { parseISO, format } from "date-fns";
import { SHA256, enc } from "crypto-js";
import { Box, LinearProgress } from "@mui/joy";

import { useGetCanisterInfo } from "@fe/integration";
import PageTemplate from "@fe/components/page-template";
import { CanisterInfoResponse } from "@declarations/history_be/history_be.did";

const CurrentState = () => {
  const { data, isLoading } = useGetCanisterInfo();

  const getModuleHash = (data: CanisterInfoResponse) => {
    const hash = SHA256(data.module_hash.join(","));
    return hash.toString(enc.Hex);
  };

  return (
    <PageTemplate title="State">
      {isLoading ? (
        <LinearProgress sx={{ marginY: 1 }} />
      ) : !data ? (
        "Something went wrong"
      ) : (
        <Box>
          <Box sx={{ marginBottom: 1 }}>
            <Box
              sx={{
                display: "inline",
                fontWeight: 600,
              }}
            >
              Module hash:
            </Box>{" "}
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
    </PageTemplate>
  );
};

export default CurrentState;
