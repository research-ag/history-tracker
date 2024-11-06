import React, { useState } from "react";
import { ArrowDownward, ArrowUpward } from "@mui/icons-material";
import { Box, IconButton, Tooltip, Typography } from "@mui/joy";

interface ItemWithDetailsProps {
  title: string;
  hash?: string;
  titleIsHash?: boolean;
  details: React.ReactNode | null;
}

const ItemWithDetails = ({
  title,
  hash,
  titleIsHash,
  details,
}: ItemWithDetailsProps) => {
  const [open, setOpen] = useState(false);

  return (
    <Box>
      <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
        {details && (
          <IconButton size="sm" onClick={() => setOpen((v) => !v)}>
            {open ? <ArrowUpward /> : <ArrowDownward />}
          </IconButton>
        )}
        <Tooltip
          title={
            hash && titleIsHash && <Box sx={{ width: "240px" }}>{hash}</Box>
          }
        >
          <Typography sx={{ display: "inline" }}>{title} </Typography>
        </Tooltip>
        {hash && !titleIsHash && (
          <Tooltip title={<Box sx={{ width: "240px" }}>{hash}</Box>}>
            <Typography sx={{ display: "inline" }}>
              ({hash.slice(0, 7)})
            </Typography>
          </Tooltip>
        )}
      </Box>
      {open && <Box sx={{ marginTop: 0.5 }}>{details}</Box>}
    </Box>
  );
};

export default ItemWithDetails;
