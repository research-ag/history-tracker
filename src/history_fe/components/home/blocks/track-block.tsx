import { Box, IconButton, Typography } from "@mui/joy";
import AddCircleOutlineIcon from "@mui/icons-material/AddCircleOutline";
import LibraryAddIcon from "@mui/icons-material/LibraryAdd";

import BlockBase from "../system/block-base";

interface TrackBlockProps {
  onTrackOne: () => void;
  onTrackMany: () => void;
}

const TrackBlock = ({ onTrackOne, onTrackMany }: TrackBlockProps) => {
  return (
    <BlockBase>
      <Typography sx={{ mb: 2 }} level="h2">
        Track new
      </Typography>
      <Typography sx={{ mb: 1 }}>Not tracking any canisters yet?</Typography>
      <Typography sx={{ mb: 3 }}>
        We will be happy to provide you with the service.
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
            onClick={onTrackOne}
            size="lg"
            variant="soft"
            color="success"
          >
            <AddCircleOutlineIcon sx={{ fontSize: "50px" }} />
          </IconButton>
          <Typography sx={{ textAlign: "center" }}>Track one</Typography>
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
            onClick={onTrackMany}
            size="lg"
            variant="soft"
            color="success"
          >
            <LibraryAddIcon sx={{ fontSize: "50px" }} />
          </IconButton>
          <Typography sx={{ textAlign: "center" }}>Track many</Typography>
        </Box>
      </Box>
    </BlockBase>
  );
};

export default TrackBlock;
