import { Box } from "@mui/joy";

import { PublicChange } from "@declarations/history_be/history_be.did";

import ItemWithDetails from "../item-with-details";

interface OriginCellProps {
  change: PublicChange;
}

const OriginCell = ({ change }: OriginCellProps) => {
  if ("from_user" in change.origin)
    return (
      <ItemWithDetails
        title="From user"
        details={
          <Box sx={{ overflowWrap: "break-word" }}>
            <Box
              sx={{
                display: "inline",
                fontWeight: 600,
              }}
            >
              Principal:
            </Box>{" "}
            {change.origin.from_user.user_id.toString()}
          </Box>
        }
      />
    );
  if ("from_canister" in change.origin)
    return (
      <ItemWithDetails
        title="From canister"
        details={
          <Box>
            <Box sx={{ overflowWrap: "break-word" }}>
              <Box
                sx={{
                  display: "inline",
                  fontWeight: 600,
                }}
              >
                Canister ID:
              </Box>{" "}
              {change.origin.from_canister.canister_id.toString()}
            </Box>
            <Box sx={{ overflowWrap: "break-word" }}>
              <Box
                sx={{
                  display: "inline",
                  fontWeight: 600,
                }}
              >
                Canister version:
              </Box>{" "}
              {change.origin.from_canister.canister_version.length
                ? Number(change.origin.from_canister.canister_version[0])
                : "N/A"}
            </Box>
          </Box>
        }
      />
    );
};

export default OriginCell;
