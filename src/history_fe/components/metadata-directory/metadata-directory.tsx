import { Link } from "react-router-dom";
import { Sheet, Box, Typography, Button, useTheme } from "@mui/joy";
import HomeIcon from "@mui/icons-material/Home";
import { useMediaQuery } from "@mui/material"; // TODO: @mui/material should not be used. Temporary solution.

import InfoItem from "@fe/components/info-item";
import { METADATA_DIRECTORY_BACKEND_CANISTER_ID } from "@fe/integration";
import { useIdentity } from "@fe/integration/identity";
import ConnectButton from "@fe/components/connect-button";
import ThemeButton from "@fe/components/theme-button";

import WasmMetadata from "./wasm-metadata";

const MetadataDirectory = () => {
  const theme = useTheme();

  const downSm = useMediaQuery(theme.breakpoints.down("sm"));

  const { identity } = useIdentity();

  const userPrincipal = identity.getPrincipal().toText();

  const isAnonymous = userPrincipal === "2vxsx-fae";

  return (
    <Box
      sx={{
        width: "100%",
        maxWidth: "990px",
        p: 4,
        mx: "auto",
      }}
    >
      <Box
        sx={{
          display: "flex",
          flexDirection: "column",
          marginBottom: 2,
        }}
      >
        <Box
          sx={{
            display: "flex",
            flexDirection: "column",
            alignItems: "flex-end",
            gap: 0.5,
            marginBottom: 1,

            [theme.breakpoints.down("sm")]: {
              alignItems: "flex-start",
              marginBottom: 2,
            },
          }}
        >
          <InfoItem label="Your principal" content={userPrincipal} withCopy />
          <InfoItem
            label="MD backend canister ID"
            content={METADATA_DIRECTORY_BACKEND_CANISTER_ID}
            withCopy
          />
        </Box>
        <Box
          sx={{
            display: "flex",
            alignItems: "center",
            justifyContent: "end",
            gap: 1,
            flexWrap: "wrap",

            [theme.breakpoints.down("sm")]: {
              flex: "1",
              justifyContent: "start",
            },
          }}
        >
          <Link style={{ display: "contents" }} to="/">
            <Button
              sx={{
                marginLeft: 1,

                [theme.breakpoints.down("sm")]: {
                  flex: "1",
                },
              }}
              variant="solid"
              color="primary"
              startDecorator={<HomeIcon />}
            >
              Home
            </Button>
          </Link>
          <ConnectButton
            sx={{
              marginLeft: 1,

              [theme.breakpoints.down("sm")]: {
                flex: "1",
              },
            }}
          />
          <ThemeButton
            sx={{
              marginLeft: 1,
            }}
          />
        </Box>
      </Box>
      <Sheet
        sx={{
          p: 2,
          display: "flex",
          flexDirection: "column",
          borderRadius: "sm",
          boxShadow: "md",
        }}
        variant="outlined"
        color="neutral"
      >
        <Typography sx={{ mb: 2 }} level={!downSm ? "h1" : "h3"} component="h1">
          Metadata directory
        </Typography>
        {isAnonymous ? (
          <Typography>
            To continue working with metadata, please sign in.
          </Typography>
        ) : (
          <Box>
            <WasmMetadata />
          </Box>
        )}
      </Sheet>
    </Box>
  );
};

export default MetadataDirectory;
