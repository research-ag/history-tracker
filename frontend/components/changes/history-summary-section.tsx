import { Box, Typography } from "@mui/joy";

import { ExtendedChange } from "@declarations/history_be/history_be.did";

import {
  getNumberOfResets,
  getSummarySinceCreation,
  getSummarySinceLastReset,
  HistorySummary,
} from "./utils";

interface HistorySummarySectionProps {
  changes?: Array<ExtendedChange>;
}

const HistorySummarySection = ({ changes }: HistorySummarySectionProps) => {
  const mapSummary = (summary: HistorySummary) => (
    <Typography
      sx={{ display: "inline", fontWeight: 600 }}
      {...(summary === "complete" && { color: "success" })}
      {...(summary === "incomplete" && { color: "warning" })}
      {...(summary === "gaps" && { color: "danger" })}
    >
      {summary}
    </Typography>
  );

  if (!changes) return null;

  const numberOfResets = getNumberOfResets(changes);

  return (
    <Box>
      <Typography level="body-sm">
        Since creation: {mapSummary(getSummarySinceCreation(changes))}
      </Typography>
      <Typography level="body-sm">
        Since last reset: {mapSummary(getSummarySinceLastReset(changes))}
      </Typography>
      <Typography level="body-sm">
        Number of resets:{" "}
        <Typography
          sx={{ display: "inline", fontWeight: 600 }}
          color={
            numberOfResets.type === "exact" && numberOfResets.resets === 0
              ? "success"
              : "warning"
          }
        >
          {numberOfResets.type === "exact"
            ? numberOfResets.resets
            : `unknown (>= ${numberOfResets.resets})`}
        </Typography>
      </Typography>
    </Box>
  );
};

export default HistorySummarySection;
