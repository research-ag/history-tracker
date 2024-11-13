import { Link } from "react-router-dom";
import { Sheet, Box, Typography, Button, CircularProgress } from "@mui/joy";
import HomeIcon from "@mui/icons-material/Home";

import InfoItem from "@fe/components/info-item";
import {
  METADATA_DIRECTORY_BACKEND_CANISTER_ID,
  useCheckMetadataDirectory,
  useCreateMetadataDirectory,
} from "@fe/integration";
import { useIdentity } from "@fe/integration/identity";
import ConnectButton from "@fe/components/connect-button";
import ThemeButton from "@fe/components/theme-button";

import WasmMetadata from "./wasm-metadata";
import Loading from "./loading";

const MetadataDirectory = () => {
  const { identity } = useIdentity();

  const userPrincipal = identity.getPrincipal().toText();

  const isAnonymous = userPrincipal === "2vxsx-fae";

  const { data: metadataExists, isLoading: checkMetadataDirectoryLoading } =
    useCheckMetadataDirectory(!isAnonymous);

  const {
    mutate: createMetadataDirectory,
    isLoading: createMetadataDirectoryLoading,
  } = useCreateMetadataDirectory();

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
          alignItems: "flex-end",
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
          }}
        >
          <InfoItem label="Your principal" content={userPrincipal} withCopy />
          <InfoItem
            label="MD backend canister ID"
            content={METADATA_DIRECTORY_BACKEND_CANISTER_ID}
            withCopy
          />
        </Box>
        <Box sx={{ display: "flex", alignItems: "center" }}>
          <Link to="/">
            <Button
              sx={{ marginLeft: 1 }}
              variant="solid"
              color="primary"
              startDecorator={<HomeIcon />}
            >
              Home
            </Button>
          </Link>
          <ConnectButton sx={{ marginLeft: 1 }} />
          <ThemeButton sx={{ marginLeft: 1 }} />
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
        <Typography sx={{ mb: 2 }} level="h1">
          Metadata directory
        </Typography>
        {isAnonymous ? (
          <Typography>
            To continue working with metadata, please sign in.
          </Typography>
        ) : checkMetadataDirectoryLoading ? (
          <Loading />
        ) : metadataExists ? (
          <Box>
            <WasmMetadata />
          </Box>
        ) : (
          <Box>
            <Box sx={{ marginBottom: 1 }}>
              Metadata directory not found. Please create metadata directory for
              your principal.
            </Box>
            <Button
              variant="solid"
              color="success"
              onClick={() => createMetadataDirectory()}
              startDecorator={
                createMetadataDirectoryLoading ? (
                  <CircularProgress size="sm" color="neutral" />
                ) : undefined
              }
              disabled={createMetadataDirectoryLoading}
            >
              Create directory
            </Button>
          </Box>
        )}
      </Sheet>
    </Box>
  );
};

export default MetadataDirectory;
