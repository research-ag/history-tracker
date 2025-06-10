import { Box, Typography, useTheme } from "@mui/joy";
import { useMediaQuery } from "@mui/material"; // TODO: @mui/material should not be used. Temporary solution.

import ConnectButton from "@fe/components/connect-button";
import ThemeButton from "@fe/components/theme-button";

import icpLogo from "./icp-logo.svg";

const Header = () => {
  const theme = useTheme();

  const downSm = useMediaQuery(theme.breakpoints.down("sm"));

  return (
    <Box
      sx={(theme) => ({
        backgroundColor: theme.palette.background.level1,
      })}
    >
      <Box
        sx={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          width: "100%",
          maxWidth: "990px",
          py: 3,
          px: 2,
          mx: "auto",
        }}
      >
        <Box>
          <Box
            sx={{
              display: "flex",
              alignItems: "center",
              gap: !downSm ? 2 : 1.5,
            }}
          >
            <img style={{ height: "24px" }} src={icpLogo} alt="ICP logo" />
            <Box sx={{ display: "flex", flexDirection: "column" }}>
              <Typography level={!downSm ? "h3" : "h4"} component="h1">
                HistoryTracker
              </Typography>
              <Typography
                sx={{
                  fontSize: "12px",
                }}
                color="neutral"
              >
                Built by MR Research AG
              </Typography>
            </Box>
          </Box>
        </Box>
        <Box
          sx={{
            display: "flex",
            alignItems: "center",
            gap: 1,
          }}
        >
          <ConnectButton iconButtonOnMobile />
          <ThemeButton />
        </Box>
      </Box>
    </Box>
  );
};

export default Header;
