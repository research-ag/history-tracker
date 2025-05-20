import { useState } from "react";
import { Principal } from "@dfinity/principal";
import { useNavigate, Link } from "react-router-dom";
import {
  Box,
  Button,
  FormControl,
  FormHelperText,
  FormLabel,
  Input,
  Typography,
  useTheme,
} from "@mui/joy";
import InfoOutlinedIcon from "@mui/icons-material/InfoOutlined";
import AddIcon from "@mui/icons-material/Add";
import { useMediaQuery } from "@mui/material"; // TODO: @mui/material should not be used. Temporary solution.

import ConnectButton from "@fe/components/connect-button";
import ThemeButton from "@fe/components/theme-button";
import InfoItem from "@fe/components/info-item";
import { useIdentity } from "@fe/integration/identity";
import { BACKEND_CANISTER_ID } from "@fe/integration";
import MetadataSourcesModal from "@fe/components/metadata-sources-modal";

import TrackModal from "./track-modal";
import icpLogo from "./icp-logo.svg";

const Home = () => {
  const theme = useTheme();

  const downMd = useMediaQuery(theme.breakpoints.down("md"));

  const navigate = useNavigate();

  const [canisterId, setCanisterId] = useState("");
  const [validationError, setValidationError] = useState(false);

  const [trackModalOpen, setTrackModalOpen] = useState(false);

  const [metadataSourcesModalOpen, setMetadataSourcesModalOpen] =
    useState(false);

  const { identity } = useIdentity();

  const userPrincipal = identity.getPrincipal().toText();

  const handleSubmit = () => {
    if (!canisterId) {
      setValidationError(true);
      return;
    }

    const isValid = (() => {
      try {
        Principal.fromText(canisterId);
        return true;
      } catch (_) {
        return false;
      }
    })();

    if (!isValid) {
      setValidationError(true);
      return;
    }

    navigate(`/dashboard/${canisterId}`);
  };

  return (
    <Box
      sx={{
        display: "flex",
        flexDirection: "column",
        width: "100%",
        maxWidth: "990px",
        py: 5,
        px: 2,
        mx: "auto",
      }}
    >
      <Box
        sx={{
          display: "flex",
          alignItems: "center",
          gap: 2,
          marginBottom: 5,
        }}
      >
        <img style={{ height: "24px" }} src={icpLogo} alt="ICP logo" />
        <Typography level="h2" component="h1">
          HistoryTracker
        </Typography>
      </Box>
      <Box
        sx={{
          display: "flex",
          flexDirection: "column",
          alignItems: "flex-start",
          gap: 0.5,
          marginBottom: 2,
        }}
      >
        <InfoItem
          label="Your principal"
          content={userPrincipal}
          withCopy
          copyAlwaysLeft
        />
        <InfoItem
          label="Backend canister ID"
          content={BACKEND_CANISTER_ID}
          withCopy
          copyAlwaysLeft
        />
      </Box>
      <Box
        sx={{
          display: "flex",
          alignItems: "center",
          gap: 1,
          marginBottom: 5,
        }}
      >
        <ConnectButton />
        <ThemeButton />
      </Box>
      <Box sx={{ marginBottom: 5 }}>
        <FormControl
          sx={{ maxWidth: "320px", marginBottom: 2 }}
          error={validationError}
        >
          <FormLabel>Canister ID:</FormLabel>
          <Input
            placeholder="Type in here…"
            autoComplete="off"
            value={canisterId}
            onChange={(e) => {
              setCanisterId(e.target.value);
              setValidationError(false);
            }}
          />
          {validationError && (
            <FormHelperText>
              <InfoOutlinedIcon />
              {!canisterId
                ? "Please enter the canister ID."
                : "Unfortunately, this is not a valid principal."}
            </FormHelperText>
          )}
        </FormControl>
        <Button color="primary" onClick={handleSubmit}>
          Go to dashboard
        </Button>
      </Box>
      <Box sx={{ marginBottom: 5 }}>
        <Typography sx={{ marginBottom: 2 }}>
          Your canister is not tracked yet?
          <br /> We will be happy to provide you with the service.
        </Typography>
        <Button
          color="success"
          startDecorator={<AddIcon />}
          onClick={() => setTrackModalOpen(true)}
        >
          Track
        </Button>
      </Box>
      <Box sx={{ marginBottom: 5 }}>
        <Typography sx={{ marginBottom: 2 }}>
          Manage and reuse metadata for your Wasm modules via Metadata
          directory.
        </Typography>
        <Button color="primary" component={Link} to="/metadata-directory">
          Go to Metadata directory
        </Button>
      </Box>
      <Box>
        <Typography sx={{ marginBottom: 2 }}>
          Specify your metadata sources here.
        </Typography>
        <Button
          color="neutral"
          onClick={() => setMetadataSourcesModalOpen(true)}
        >
          Metadata sources
        </Button>
      </Box>
      <TrackModal
        isOpen={trackModalOpen}
        onClose={() => setTrackModalOpen(false)}
      />
      <MetadataSourcesModal
        isOpen={metadataSourcesModalOpen}
        onClose={() => setMetadataSourcesModalOpen(false)}
      />
    </Box>
  );
};

export default Home;
