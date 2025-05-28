import { Box, Typography } from "@mui/joy";
import { format, formatDuration, intervalToDuration } from "date-fns";

import {
  useGetLastRoundDetails,
  useGetTrackingStats,
  useGetTrackedCanistersTotal,
} from "@fe/integration";

import BlockBase from "../system/block-base";

const StatsBlock = () => {
  const {
    data: trackedCanistersTotal,
    isLoading: isTrackedCanistersTotalLoading,
  } = useGetTrackedCanistersTotal();

  const { data: trackingStats, isLoading: isTrackingStatsLoading } =
    useGetTrackingStats();

  const { data: lastRoundDetails, isLoading: isLastRoundDetailsLoading } =
    useGetLastRoundDetails();

  const formattedTrackedCanistersTotal = trackedCanistersTotal
    ? trackedCanistersTotal.toString()
    : isTrackedCanistersTotalLoading
    ? "Loading..."
    : "N/A";

  const formattedNewIn24h = trackingStats
    ? `+${trackingStats.new_24h.toString()}`
    : isTrackingStatsLoading
    ? "Loading..."
    : "N/A";

  const formattedNewIn7d = trackingStats
    ? `+${trackingStats.new_7d.toString()}`
    : isTrackingStatsLoading
    ? "Loading..."
    : "N/A";

  const formattedNewIn30d = trackingStats
    ? `+${trackingStats.new_30d.toString()}`
    : isTrackingStatsLoading
    ? "Loading..."
    : "N/A";

  const lastSyncCompletedAt = lastRoundDetails
    ? format(
        new Date(Number(lastRoundDetails.completed_at) / 1_000_000),
        "MMM dd, yyyy HH:mm"
      )
    : isLastRoundDetailsLoading
    ? "Loading..."
    : "N/A";

  const lastSyncDuration = lastRoundDetails
    ? formatDuration(
        intervalToDuration({
          start: new Date(0),
          end: new Date(Number(lastRoundDetails.duration) * 1_000),
        }),
        { format: ["minutes", "seconds"] }
      )
    : isLastRoundDetailsLoading
    ? "Loading..."
    : "N/A";

  return (
    <BlockBase>
      <Typography sx={{ mb: 2 }} level="h2">
        Activity stats
      </Typography>
      <Box>Tracked cansiters: {formattedTrackedCanistersTotal}</Box>
      <Box>New in 24 hours: {formattedNewIn24h}</Box>
      <Box>New in 7 days: {formattedNewIn7d}</Box>
      <Box>New in 1 month: {formattedNewIn30d}</Box>
      <Box>Last sync completed at: {lastSyncCompletedAt}</Box>
      <Box>Last sync duration: {lastSyncDuration}</Box>
    </BlockBase>
  );
};

export default StatsBlock;
