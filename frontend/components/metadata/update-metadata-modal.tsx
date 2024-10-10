import { useEffect, useMemo } from "react";
import {
  useForm,
  SubmitHandler,
  Controller,
  useFormState,
} from "react-hook-form";
import { Principal } from "@dfinity/principal";
import { zodResolver } from "@hookform/resolvers/zod";
import { z as zod } from "zod";
import {
  Box,
  Modal,
  ModalDialog,
  ModalClose,
  FormControl,
  FormLabel,
  Input,
  Typography,
  Button,
} from "@mui/joy";

import { useUpdateCanisterMetadata } from "@fe/integration";
import ErrorAlert from "@fe/components/error-alert";
import { CanisterMetadataResponse } from "@declarations/history_be/history_be.did";

interface UpdateMetadataFormValues {
  name: string;
  description: string;
}

interface UpdateMetadataModalProps {
  canisterId: Principal;
  metadata: CanisterMetadataResponse;
  isOpen: boolean;
  onClose: () => void;
}

const schema = zod.object({
  name: zod.string(),
  description: zod.string(),
});

const UpdateMetadataModal = ({
  canisterId,
  metadata,
  isOpen,
  onClose,
}: UpdateMetadataModalProps) => {
  const defaultValues: UpdateMetadataFormValues = useMemo(
    () => ({
      name: metadata.name,
      description: metadata.description,
    }),
    []
  );

  const {
    handleSubmit,
    control,
    reset: resetForm,
  } = useForm<UpdateMetadataFormValues>({
    defaultValues,
    resolver: zodResolver(schema),
    mode: "onChange",
  });

  const { isDirty, isValid } = useFormState({ control });

  const {
    mutate: updateCanisterMetadata,
    error,
    isLoading,
    reset: resetApi,
  } = useUpdateCanisterMetadata();

  const submit: SubmitHandler<UpdateMetadataFormValues> = (data) => {
    updateCanisterMetadata(
      { canisterId, name: data.name, description: data.description },
      {
        onSuccess: () => {
          onClose();
        },
      }
    );
  };

  useEffect(() => {
    resetForm(defaultValues);
    resetApi();
  }, [isOpen]);

  return (
    <Modal open={isOpen} onClose={onClose}>
      <ModalDialog sx={{ width: "calc(100% - 50px)", maxWidth: "450px" }}>
        <ModalClose />
        <Typography level="h4">Update metadata</Typography>
        <form onSubmit={handleSubmit(submit)} autoComplete="off">
          <Box sx={{ display: "flex", flexDirection: "column", gap: 1 }}>
            <Controller
              name="name"
              control={control}
              render={({ field, fieldState }) => (
                <FormControl>
                  <FormLabel>Name</FormLabel>
                  <Input
                    type="text"
                    variant="outlined"
                    name={field.name}
                    value={field.value}
                    onChange={field.onChange}
                    autoComplete="off"
                    error={!!fieldState.error}
                  />
                </FormControl>
              )}
            />
            <Controller
              name="description"
              control={control}
              render={({ field, fieldState }) => (
                <FormControl>
                  <FormLabel>Description</FormLabel>
                  <Input
                    type="text"
                    variant="outlined"
                    name={field.name}
                    value={field.value}
                    onChange={field.onChange}
                    autoComplete="off"
                    error={!!fieldState.error}
                  />
                </FormControl>
              )}
            />
          </Box>
          {!!error && <ErrorAlert errorMessage={(error as Error).message} />}
          <Button
            sx={{ marginTop: 2 }}
            variant="solid"
            loading={isLoading}
            type="submit"
            disabled={!isValid || !isDirty}
          >
            Update
          </Button>
        </form>
      </ModalDialog>
    </Modal>
  );
};

export default UpdateMetadataModal;
