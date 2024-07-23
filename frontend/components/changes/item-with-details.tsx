import { ArrowDownward, ArrowUpward } from "@mui/icons-material";
import { Box, IconButton } from "@mui/joy";
import React, { useState } from "react";

interface ItemWithDetailsProps {
  title: string;
  details: React.ReactNode | null;
}

const ItemWithDetails = ({ title, details }: ItemWithDetailsProps) => {
  const [open, setOpen] = useState(false);

  return (
    <Box>
      <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
        {details && (
          <IconButton size="sm" onClick={() => setOpen((v) => !v)}>
            {open ? <ArrowUpward /> : <ArrowDownward />}
          </IconButton>
        )}
        {title}
      </Box>
      {open && <Box sx={{ marginTop: 0.5 }}>{details}</Box>}
    </Box>
  );
};

export default ItemWithDetails;
