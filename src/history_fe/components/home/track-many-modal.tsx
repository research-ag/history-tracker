import { useEffect, useMemo } from "react";
import {
  useForm,
  SubmitHandler,
  Controller,
  useFormState,
} from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z as zod } from "zod";
import {
  Button,
  FormControl,
  FormLabel,
  Modal,
  ModalDialog,
  ModalClose,
  CircularProgress,
  Box,
  Typography,
  Textarea,
  Link,
} from "@mui/joy";

import { useTrackMany } from "@fe/integration";
import { textToPrincipals, validatePrincipals } from "@fe/utils/principal";

import ErrorAlert from "../error-alert";

interface TrackManyFormValues {
  canisterIds: string;
}

interface TrackModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const schema = zod.object({
  canisterIds: zod.string().refine(validatePrincipals, "Not valid."),
});

const TrackManyModal = ({ isOpen, onClose }: TrackModalProps) => {
  const {
    data,
    mutate,
    isLoading,
    error,
    reset: resetMutation,
  } = useTrackMany();

  const defaultValues = useMemo<TrackManyFormValues>(
    () => ({
      canisterIds: "",
    }),
    []
  );

  const { handleSubmit, control, reset } = useForm<TrackManyFormValues>({
    defaultValues,
    resolver: zodResolver(schema),
    mode: "onChange",
  });

  const { isDirty, isValid } = useFormState({ control });

  const submit: SubmitHandler<TrackManyFormValues> = (data) => {
    mutate(textToPrincipals(data.canisterIds));
  };

  useEffect(() => {
    if (!isOpen) {
      resetMutation();
      reset(defaultValues);
    }
  }, [isOpen]);

  useEffect(() => {
    reset(defaultValues);
  }, [defaultValues]);

  return (
    <Modal open={isOpen} onClose={onClose}>
      <ModalDialog sx={{ width: "calc(100% - 50px)", maxWidth: "700px" }}>
        <ModalClose />
        <Typography level="h4">Track multiple canisters</Typography>
        <Box sx={{ overflow: "auto" }}>
          {data ? (
            <Box sx={{ display: "flex", flexDirection: "column", gap: 2 }}>
              {data.map((res, i) => (
                <Box
                  sx={{ display: "flex", flexDirection: "column", gap: 0.5 }}
                  key={res.canisterId}
                >
                  <Typography level="body-sm">
                    {i + 1}. Canister ID:{" "}
                    {res.ok ? (
                      <Link
                        href={`/dashboard/${res.canisterId}`}
                        target="_blank"
                      >
                        {res.canisterId}
                      </Link>
                    ) : (
                      res.canisterId
                    )}
                  </Typography>
                  <Typography level="body-sm">
                    Status:{" "}
                    <Typography
                      component="span"
                      color={res.ok ? "success" : "danger"}
                    >
                      {res.ok ? "Success" : "Error"}
                    </Typography>
                  </Typography>
                  {!res.ok && (
                    <Typography level="body-sm">
                      Reason: {res.data.message}
                    </Typography>
                  )}
                </Box>
              ))}
            </Box>
          ) : (
            <form onSubmit={handleSubmit(submit)} autoComplete="off">
              <Box sx={{ display: "flex", flexDirection: "column", gap: 1 }}>
                <Controller
                  name="canisterIds"
                  control={control}
                  render={({ field, fieldState }) => (
                    <FormControl>
                      <FormLabel>Canisters to track (principals)</FormLabel>
                      <Textarea
                        variant="outlined"
                        name={field.name}
                        value={field.value}
                        onChange={field.onChange}
                        autoComplete="off"
                        minRows={5}
                        maxRows={5}
                        error={!!fieldState.error}
                      />
                    </FormControl>
                  )}
                />
                {!!error && (
                  <ErrorAlert errorMessage={(error as Error).message} />
                )}
              </Box>
              <Button
                sx={{ marginTop: 2 }}
                variant="solid"
                type="submit"
                disabled={isLoading || !isValid || !isDirty}
                startDecorator={isLoading && <CircularProgress />}
              >
                Track
              </Button>
            </form>
          )}
        </Box>
      </ModalDialog>
    </Modal>
  );
};

export default TrackManyModal;
