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
  Textarea,
} from "@mui/joy";

import {
  useMetadataSources,
  validateMetadataSources,
  principalsToText,
  textToPrincipals,
} from "@fe/utils/metadata-sources";

interface MetadataSourcesFormValues {
  sources: string;
}

interface MetadataSourcesModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const schema = zod.object({
  sources: zod.string().refine(validateMetadataSources, "Not valid."),
});

const MetadataSourcesModal = ({
  isOpen,
  onClose,
}: MetadataSourcesModalProps) => {
  const { metadataSources, setMetadataSources } = useMetadataSources();

  const defaultValues = useMemo<MetadataSourcesFormValues>(
    () => ({
      sources: principalsToText(metadataSources),
    }),
    [metadataSources]
  );

  const { handleSubmit, control, reset } = useForm<MetadataSourcesFormValues>({
    defaultValues,
    resolver: zodResolver(schema),
    mode: "onChange",
  });

  const { isDirty, isValid } = useFormState({ control });

  const submit: SubmitHandler<MetadataSourcesFormValues> = (data) => {
    setMetadataSources(textToPrincipals(data.sources));
  };

  useEffect(() => {
    reset(defaultValues);
  }, [defaultValues]);

  return (
    <Modal open={isOpen} onClose={onClose}>
      <ModalDialog sx={{ width: "calc(100% - 50px)", maxWidth: "700px" }}>
        <ModalClose />
        <Typography level="h4">Metadata sources</Typography>
        <form onSubmit={handleSubmit(submit)} autoComplete="off">
          <Box sx={{ display: "flex", flexDirection: "column", gap: 1 }}>
            <Controller
              name="sources"
              control={control}
              render={({ field, fieldState }) => (
                <FormControl>
                  <FormLabel>Sources</FormLabel>
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
          </Box>
          <Button
            sx={{ marginTop: 2 }}
            variant="solid"
            type="submit"
            disabled={!isValid || !isDirty}
          >
            Save
          </Button>
        </form>
      </ModalDialog>
    </Modal>
  );
};

export default MetadataSourcesModal;
