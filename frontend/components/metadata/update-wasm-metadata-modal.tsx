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
  Typography,
  Button,
} from "@mui/joy";
import MDEditor from "@uiw/react-md-editor";

import { useUpdateWasmMetadata } from "@fe/integration";
import ErrorAlert from "@fe/components/error-alert";
import { PublicWasmMetadata } from "@declarations/history_be/history_be.did";

interface UpdateWasmMetadataFormValues {
  buildInstructions: string;
}

interface UpdateWasmMetadataModalProps {
  canisterId: Principal;
  wasmMetadata: PublicWasmMetadata | null;
  isOpen: boolean;
  onClose: () => void;
}

const schema = zod.object({
  buildInstructions: zod.string(),
});

const UpdateWasmMetadataModal = ({
  canisterId,
  wasmMetadata,
  isOpen,
  onClose,
}: UpdateWasmMetadataModalProps) => {
  const defaultValues: UpdateWasmMetadataFormValues = useMemo(
    () => ({
      buildInstructions: wasmMetadata?.build_instructions ?? "",
    }),
    [wasmMetadata]
  );

  const {
    handleSubmit,
    control,
    reset: resetForm,
  } = useForm<UpdateWasmMetadataFormValues>({
    defaultValues,
    resolver: zodResolver(schema),
    mode: "onChange",
  });

  const { isDirty, isValid } = useFormState({ control });

  const {
    mutate: updateWasmMetadata,
    error,
    isLoading,
    reset: resetApi,
  } = useUpdateWasmMetadata();

  const submit: SubmitHandler<UpdateWasmMetadataFormValues> = (data) => {
    updateWasmMetadata(
      {
        canisterId,
        module_hash: wasmMetadata!.module_hash,
        build_instructions: data.buildInstructions,
      },
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
      <ModalDialog sx={{ width: "calc(100% - 50px)", maxWidth: "700px" }}>
        <ModalClose />
        <Typography level="h4">Update Wasm metadata</Typography>
        <form onSubmit={handleSubmit(submit)} autoComplete="off">
          <Box sx={{ display: "flex", flexDirection: "column", gap: 1 }}>
            <Controller
              name="buildInstructions"
              control={control}
              render={({ field }) => (
                <FormControl>
                  <FormLabel>Build instructions (Markdown format)</FormLabel>
                  <MDEditor value={field.value} onChange={field.onChange} />
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

export default UpdateWasmMetadataModal;
