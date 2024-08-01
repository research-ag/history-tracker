import { Box, Typography } from "@mui/joy";

interface GapsRowContentProps {
  gaps: number;
}

const GapsRowContent = ({ gaps }: GapsRowContentProps) => {
  return (
    <Box
      sx={{
        display: "flex",
        alignItems: "center",
        gap: 2,
      }}
    >
      <Typography sx={{ display: "inline", fontWeight: 600 }} color="warning">
        WARNING
      </Typography>
      <Typography>
        Gap of{" "}
        <Typography sx={{ display: "inline", fontWeight: 600 }}>
          {gaps}
        </Typography>{" "}
        change
        {gaps > 1 ? "s" : ""}
      </Typography>
    </Box>
  );
};

export default GapsRowContent;
