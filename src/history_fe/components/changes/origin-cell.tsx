import { Box } from "@mui/joy";

import { ExtendedChange } from "@bindings/history_be";

import ItemWithDetails from "./item-with-details";

interface OriginCellProps {
  change: ExtendedChange;
}

const OriginCell = ({ change }: OriginCellProps) => {
  if (change.origin?.__kind__ === "from_user")
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
  if (change.origin?.__kind__ === "from_canister")
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
              {typeof change.origin.from_canister.canister_version !==
              "undefined"
                ? Number(change.origin.from_canister.canister_version)
                : "N/A"}
            </Box>
          </Box>
        }
      />
    );
};

export default OriginCell;
