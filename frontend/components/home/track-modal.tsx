import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Principal } from "@dfinity/principal";
import {
  Button,
  FormControl,
  FormHelperText,
  FormLabel,
  Input,
  Typography,
  Modal,
  ModalDialog,
  ModalClose,
  Sheet,
  CircularProgress,
} from "@mui/joy";
import InfoOutlinedIcon from "@mui/icons-material/InfoOutlined";

import { useTrack } from "@fe/integration";

interface TrackModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const TrackModal = ({ isOpen, onClose }: TrackModalProps) => {
  const navigate = useNavigate();

  const [canisterId, setCanisterId] = useState("");
  const [validationError, setValidationError] = useState(false);
  const [apiError, setApiError] = useState("");

  const { mutate, isLoading } = useTrack();

  const handleClose = () => {
    onClose();
    setCanisterId("");
    setValidationError(false);
    setApiError("");
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
      onError: (error) => setApiError((error as { message: string }).message),
    });
  };

  return (
    <Modal open={isOpen} onClose={handleClose}>
      <ModalDialog sx={{ width: "calc(100% - 50px)", maxWidth: "450px" }}>
        <ModalClose />
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
        <Button
          color="success"
          disabled={isLoading}
          startDecorator={isLoading && <CircularProgress />}
          onClick={handleSubmit}
        >
          Register the canister
        </Button>
        {apiError && (
          <Sheet sx={{ p: 1 }} variant="outlined" color="neutral">
            <Typography
              sx={{ overflow: "auto", width: "100%" }}
              level="body-xs"
              color="danger"
              component="pre"
            >
              {apiError}
            </Typography>
          </Sheet>
        )}
      </ModalDialog>
    </Modal>
  );
};

export default TrackModal;
