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
  Box,
  Modal,
  ModalDialog,
  ModalClose,
  FormControl,
  FormLabel,
  Typography,
  Button,
  Input,
} from "@mui/joy";
import MDEditor from "@uiw/react-md-editor";

import { useAddWasmMetadata, useUpdateWasmMetadata } from "@fe/integration";
import ErrorAlert from "@fe/components/error-alert";
import { WasmMetadata } from "@declarations/metadata_directory/metadata_directory.did";
import {
  fromSHA256Hash,
  getSHA256Hash,
  isValidSHA256Hash,
} from "@fe/utils/hash";

interface WasmMetadataFormValues {
  moduleHash: string;
  description: string;
  buildInstructions: string;
}

interface WasmMetadataModalProps {
  wasmMetadata: WasmMetadata | null;
  isOpen: boolean;
  onClose: () => void;
}

const schema = zod.object({
  moduleHash: zod
    .string()
    .refine(isValidSHA256Hash, "Module hash is not valid."),
  description: zod.string(),
  buildInstructions: zod.string(),
});

const WasmMetadataModal = ({
  wasmMetadata,
  isOpen,
  onClose,
}: WasmMetadataModalProps) => {
  const defaultValues = useMemo<WasmMetadataFormValues>(
    () => ({
      moduleHash: wasmMetadata ? getSHA256Hash(wasmMetadata.module_hash) : "",
      description: wasmMetadata?.description ?? "",
      buildInstructions: wasmMetadata?.build_instructions ?? "",
    }),
    [wasmMetadata]
  );

  const {
    handleSubmit,
    control,
    reset: resetForm,
  } = useForm<WasmMetadataFormValues>({
    defaultValues,
    resolver: zodResolver(schema),
    mode: "onChange",
  });

  const { isDirty, isValid } = useFormState({ control });

  const {
    mutate: addWasmMetadata,
    error: addWasmMetadataError,
    isLoading: addWasmMetadataLoading,
    reset: resetAddApi,
  } = useAddWasmMetadata();

  const {
    mutate: updateWasmMetadata,
    error: updateWasmMetadataError,
    isLoading: updateWasmMetadataLoading,
    reset: resetUpdateApi,
  } = useUpdateWasmMetadata();

  const error = addWasmMetadataError || updateWasmMetadataError;
  const isLoading = addWasmMetadataLoading || updateWasmMetadataLoading;

  const submit: SubmitHandler<WasmMetadataFormValues> = (data) => {
    if (wasmMetadata) {
      updateWasmMetadata(
        {
          moduleHash: wasmMetadata!.module_hash,
          description: data.description,
          buildInstructions: data.buildInstructions,
        },
        {
          onSuccess: () => {
            onClose();
          },
        }
      );
      return;
    }

    addWasmMetadata(
      {
        moduleHash: fromSHA256Hash(data.moduleHash),
        description: data.description,
        buildInstructions: data.buildInstructions,
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
    resetAddApi();
    resetUpdateApi();
  }, [isOpen]);

  return (
    <Modal open={isOpen} onClose={onClose}>
      <ModalDialog sx={{ width: "calc(100% - 50px)", maxWidth: "700px" }}>
        <ModalClose />
        <Typography level="h4">
          {wasmMetadata ? "Update" : "Add"} Wasm metadata
        </Typography>
        <form onSubmit={handleSubmit(submit)} autoComplete="off">
          <Box sx={{ display: "flex", flexDirection: "column", gap: 1 }}>
            <Controller
              name="moduleHash"
              control={control}
              render={({ field, fieldState }) => (
                <FormControl>
                  <FormLabel>Module hash</FormLabel>
                  <Input
                    type="text"
                    variant="outlined"
                    name={field.name}
                    value={field.value}
                    onChange={field.onChange}
                    autoComplete="off"
                    error={!!fieldState.error}
                    disabled={!!wasmMetadata}
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
            {wasmMetadata ? "Update" : "Add"}
          </Button>
        </form>
      </ModalDialog>
    </Modal>
  );
};

export default WasmMetadataModal;
