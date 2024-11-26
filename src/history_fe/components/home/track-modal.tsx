import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Principal } from "@dfinity/principal";
import {
  Button,
  FormControl,
  FormHelperText,
  FormLabel,
  Input,
  Modal,
  ModalDialog,
  ModalClose,
  CircularProgress,
  Box,
} from "@mui/joy";
import InfoOutlinedIcon from "@mui/icons-material/InfoOutlined";

import { useTrack } from "@fe/integration";

import ErrorAlert from "../error-alert";

interface TrackModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const TrackModal = ({ isOpen, onClose }: TrackModalProps) => {
  const navigate = useNavigate();

  const [canisterId, setCanisterId] = useState("");
  const [validationError, setValidationError] = useState(false);

  const { mutate, error, isLoading, reset: resetApi } = useTrack();

  const handleClose = () => {
    onClose();
    setCanisterId("");
    setValidationError(false);
    resetApi();
  };

  const handleSubmit = () => {
    if (!canisterId) {
      setValidationError(true);
      return;
    }

    let principal: Principal;

    const isValid = (() => {
      try {
        principal = Principal.fromText(canisterId);
        return true;
      } catch (_) {
        return false;
      }
    })();

    if (!isValid) {
      setValidationError(true);
      return;
    }

    mutate(principal!, {
      onSuccess: () => navigate(`/dashboard/${canisterId}`),
    });
  };

  return (
    <Modal open={isOpen} onClose={handleClose}>
      <ModalDialog sx={{ width: "calc(100% - 50px)", maxWidth: "450px" }}>
        <ModalClose />
        <Box>
          <FormControl error={validationError}>
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
          {!!error && <ErrorAlert errorMessage={(error as Error).message} />}
          <Button
            sx={{ marginTop: 2 }}
            color="success"
            disabled={isLoading}
            startDecorator={isLoading && <CircularProgress />}
            onClick={handleSubmit}
          >
            Register the canister
          </Button>
        </Box>
      </ModalDialog>
    </Modal>
  );
};

export default TrackModal;
