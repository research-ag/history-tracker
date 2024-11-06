import { Box, Typography, CircularProgress } from "@mui/joy";

const Loading = () => {
  return (
    <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
      <CircularProgress size="sm" />
      <Typography level="h3" color="primary">
        Loading...
      </Typography>
    </Box>
  );
};

export default Loading;
