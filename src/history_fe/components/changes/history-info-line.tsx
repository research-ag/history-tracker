import { format } from "date-fns";
import { Box, Divider, Typography, useTheme } from "@mui/joy";
import { useMediaQuery } from "@mui/material"; // TODO: @mui/material should not be used. Temporary solution.

import { CanisterChangesResponse } from "@declarations/history_be/history_be.did";
import { SxProps } from "@mui/joy/styles/types";

interface HistoryInfoLineProps {
  sx?: SxProps;
  data: CanisterChangesResponse;
}

const HistoryInfoLine = ({ sx, data }: HistoryInfoLineProps) => {
  const theme = useTheme();

  const downSm = useMediaQuery(theme.breakpoints.down("sm"));

  return (
    <Box
      sx={{
        display: "flex",
        alignItems: "center",
        columnGap: 2,
        ...(downSm && {
          flexDirection: "column",
          alignItems: "start",
        }),
        ...sx,
      }}
    >
      <Typography level="body-xs">
        Total records: {Number(data.total_num_changes)}
      </Typography>
      {!downSm && <Divider orientation="vertical" />}
      <Typography level="body-xs">
        Tracked records: {data.changes.length}
      </Typography>
      {!downSm && <Divider orientation="vertical" />}
      <Typography level="body-xs">
        History completeness:{" "}
        {data.total_num_changes > 0
          ? `${(
              (data.changes.length / Number(data.total_num_changes)) *
              100
            ).toFixed(2)}%`
          : "N/A"}
      </Typography>
      {!downSm && <Divider orientation="vertical" />}
      <Typography level="body-xs">
        Latest sync:{" "}
        {format(
          new Date(Number(data.timestamp_nanos) / 1_000_000),
          "MMM dd, yyyy HH:mm"
        )}
      </Typography>
    </Box>
  );
};

export default HistoryInfoLine;
