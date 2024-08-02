import React, { useState } from "react";
import { ArrowDownward, ArrowUpward } from "@mui/icons-material";
import { Box, IconButton, Tooltip, Typography } from "@mui/joy";

interface ItemWithDetailsProps {
  title: string;
  hash?: string;
  details: React.ReactNode | null;
}

const ItemWithDetails = ({ title, hash, details }: ItemWithDetailsProps) => {
  const [open, setOpen] = useState(false);

  return (
    <Box>
      <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
        {details && (
          <IconButton size="sm" onClick={() => setOpen((v) => !v)}>
            {open ? <ArrowUpward /> : <ArrowDownward />}
          </IconButton>
        )}
        {title}{" "}
        {hash && (
          <Tooltip title={hash}>
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
