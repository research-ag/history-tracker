import { Box, CircularProgress, Typography } from "@mui/joy";

const LoadingPage = () => {
  return (
    <Box
      sx={{
        width: "100%",
        maxWidth: "990px",
        p: 4,
        mx: "auto",
      }}
    >
      <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
        <CircularProgress size="sm" />
        <Typography level="h3" color="primary">
          Loading...
        </Typography>
      </Box>
    </Box>
  );
};

export default LoadingPage;
