import { Box, Modal, ModalDialog, ModalClose, Typography } from "@mui/joy";
import MDEditor from "@uiw/react-md-editor";

interface ViewBuildInstructionsModalProps {
  buildInstructions: string;
  isOpen: boolean;
  onClose: () => void;
}

const ViewBuildInstructionsModal = ({
  buildInstructions,
  isOpen,
  onClose,
}: ViewBuildInstructionsModalProps) => {
  return (
    <Modal open={isOpen} onClose={onClose}>
      <ModalDialog sx={{ width: "calc(100% - 50px)", maxWidth: "700px" }}>
        <ModalClose />
        <Typography level="h4">View build instructions</Typography>
        <Box
          sx={{
            border: (theme) =>
              `1px solid ${theme.palette.primary.outlinedBorder}`,
          }}
        >
          <MDEditor.Markdown
            style={{ padding: "8px" }}
            source={buildInstructions}
          />
        </Box>
      </ModalDialog>
    </Modal>
  );
};

export default ViewBuildInstructionsModal;
