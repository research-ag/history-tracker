import { useState } from "react";
import { Principal } from "@dfinity/principal";
import { useNavigate } from "react-router-dom";
import {
  Button,
  FormControl,
  FormHelperText,
  FormLabel,
  Input,
  Typography,
} from "@mui/joy";
import InfoOutlinedIcon from "@mui/icons-material/InfoOutlined";
import ArrowForwardIcon from "@mui/icons-material/ArrowForward";

import BlockBase from "../system/block-base";

const DashboardBlock = () => {
  const navigate = useNavigate();

  const [canisterId, setCanisterId] = useState("");
  const [validationError, setValidationError] = useState(false);

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
    <BlockBase>
      <Typography sx={{ mb: 2 }} level="h2">
        Dashboard
      </Typography>
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
      <Button
        startDecorator={<ArrowForwardIcon />}
        color="primary"
        onClick={handleSubmit}
      >
        Open history dashboard
      </Button>
    </BlockBase>
  );
};

export default DashboardBlock;
