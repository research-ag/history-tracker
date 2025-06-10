import { Link } from "react-router-dom";
import { Box, IconButton, Typography } from "@mui/joy";
import FolderOpenIcon from "@mui/icons-material/FolderOpen";
import TuneIcon from "@mui/icons-material/Tune";

import BlockBase from "../system/block-base";

interface MetadataBlockProps {
  onMetadataSourcesClick: () => void;
}

const MetadataBlock = ({ onMetadataSourcesClick }: MetadataBlockProps) => {
  return (
    <BlockBase>
      <Typography sx={{ mb: 2 }} level="h2">
        Metadata
      </Typography>
      <Typography sx={{ mb: 3 }}>
        Manage and reuse metadata for Wasm modules by using the Metadata
        Directory and specifying your custom sources.
      </Typography>
      <Box
        sx={{
          display: "flex",
          justifyContent: "space-around",
          alignItems: "center",
        }}
      >
        <Box
          sx={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 1,
          }}
        >
          <IconButton
            sx={{ width: "70px", height: "70px" }}
            component={Link}
            to="/metadata-directory"
            size="lg"
            variant="soft"
            color="neutral"
          >
            <FolderOpenIcon sx={{ fontSize: "50px" }} />
          </IconButton>
          <Typography sx={{ textAlign: "center" }}>Directory</Typography>
        </Box>
        <Box
          sx={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 1,
          }}
        >
          <IconButton
            sx={{ width: "70px", height: "70px" }}
            onClick={onMetadataSourcesClick}
            size="lg"
            variant="soft"
            color="neutral"
          >
            <TuneIcon sx={{ fontSize: "50px" }} />
          </IconButton>
          <Typography sx={{ textAlign: "center" }}>Sources</Typography>
        </Box>
      </Box>
    </BlockBase>
  );
};

export default MetadataBlock;
