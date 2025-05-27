import { Box, Typography } from "@mui/joy";

import BlockBase from "../system/block-base";

const StatsBlock = () => {
  return (
    <BlockBase>
      <Typography sx={{ mb: 2 }} level="h2">
        Activity stats
      </Typography>
      <Box>Tracked cansiters: 99999</Box>
      <Box>New in 24 hours: +100</Box>
      <Box>New in 7 days: +100</Box>
      <Box>New in 1 month: +100</Box>
      <Box>Last sync completed at: X</Box>
      <Box>Last sync duration: X</Box>
    </BlockBase>
  );
};

export default StatsBlock;
