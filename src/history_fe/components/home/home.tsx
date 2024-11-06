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
} from "@mui/joy";
import InfoOutlinedIcon from "@mui/icons-material/InfoOutlined";
import AddIcon from "@mui/icons-material/Add";

import ConnectButton from "@fe/components/connect-button";
import ThemeButton from "@fe/components/theme-button";
import InfoItem from "@fe/components/info-item";
import { useIdentity } from "@fe/integration/identity";
import { BACKEND_CANISTER_ID } from "@fe/integration";

import TrackModal from "./track-modal";
import icpLogo from "./icp-logo.svg";

const Home = () => {
  const navigate = useNavigate();

  const [canisterId, setCanisterId] = useState("");
  const [validationError, setValidationError] = useState(false);

  const [trackModalOpen, setTrackModalOpen] = useState(false);

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
          gap: 0.5,
          marginBottom: 1,
        }}
      >
        <InfoItem label="Your principal" content={userPrincipal} withCopy />
        <InfoItem
          label="Backend canister ID"
          content={BACKEND_CANISTER_ID}
          withCopy
        />
      </Box>
      <Box
        sx={{ display: "flex", alignItems: "center", gap: 3, marginBottom: 5 }}
      >
        <img style={{ height: "24px" }} src={icpLogo} alt="ICP logo" />
        <Typography level="h1">ICP History Tracker</Typography>
        <Box
          sx={{
            display: "flex",
            alignItems: "center",
            gap: 1,
            marginLeft: "auto",
          }}
        >
          <ConnectButton />
          <ThemeButton />
        </Box>
      </Box>
      <Box sx={{ marginBottom: 5 }}>
        <FormControl
          sx={{ width: "320px", marginBottom: 2 }}
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
          Manage and reuse metadata for your Wasm modules
          <br />
          via CMM (Controller-Managed Metadata).
        </Typography>
        <Button color="primary" component={Link} to="/cmm">
          Go to CMM
        </Button>
      </Box>
      <Box>
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
      <TrackModal
        isOpen={trackModalOpen}
        onClose={() => setTrackModalOpen(false)}
      />
    </Box>
  );
};

export default Home;
