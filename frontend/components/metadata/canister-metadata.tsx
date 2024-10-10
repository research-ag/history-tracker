import { Box } from "@mui/joy";

import { CanisterMetadataResponse } from "@declarations/history_be/history_be.did";

interface CanisterMetadataProps {
  data: CanisterMetadataResponse;
}

const CanisterMetadata = ({ data }: CanisterMetadataProps) => {
  return (
    <Box>
      <Box sx={{ marginBottom: 1 }}>
        <Box sx={{ display: "inline", fontWeight: 600 }}>Name:</Box>{" "}
        <Box sx={{ display: "inline" }}>{data.name}</Box>
      </Box>
      <Box>
        <Box sx={{ display: "inline", fontWeight: 600 }}>Description:</Box>{" "}
        <Box sx={{ display: "inline" }}>{data.description}</Box>
      </Box>
    </Box>
  );
};

export default CanisterMetadata;
