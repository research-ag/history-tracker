import { format } from "date-fns";
import { Box, Divider, Typography } from "@mui/joy";

import { CanisterChangesResponse } from "@declarations/history_be/history_be.did";

interface HistoryInfoLineProps {
  data: CanisterChangesResponse;
}

const HistoryInfoLine = ({ data }: HistoryInfoLineProps) => {
  return (
    <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
      <Typography level="body-xs">
        Total records: {Number(data.total_num_changes)}
      </Typography>
      <Divider orientation="vertical" />
      <Typography level="body-xs">
        Tracked records: {data.changes.length}
      </Typography>
      <Divider orientation="vertical" />
      <Typography level="body-xs">
        History completeness:{" "}
        {data.total_num_changes > 0
          ? `${(
              (data.changes.length / Number(data.total_num_changes)) *
              100
            ).toFixed(2)}%`
          : "N/A"}
      </Typography>
      <Divider orientation="vertical" />
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
