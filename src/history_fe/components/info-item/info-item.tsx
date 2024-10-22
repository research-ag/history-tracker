import { useRef, useState } from "react";
import { Box, Typography, Tooltip } from "@mui/joy";
import ContentCopyIcon from "@mui/icons-material/ContentCopy";

interface InfoItemProps {
  label: string;
  content: string;
  withCopy?: boolean;
}

const InfoItem = ({ label, content, withCopy }: InfoItemProps) => {
  const timerID = useRef<NodeJS.Timeout | null>(null);

  const [isCopied, setIsCopied] = useState(false);

  const copyTooltipTitle = isCopied ? "✓ Copied" : "Copy to clipboard";

  return (
    <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
      <Typography sx={{ fontWeight: 700 }} level="body-xs">
        {label}:{" "}
      </Typography>
      <Typography level="body-xs">{content}</Typography>
      {withCopy && (
        <Tooltip title={copyTooltipTitle} disableInteractive>
          <ContentCopyIcon
            sx={{ fontSize: "16px", cursor: "pointer", marginLeft: 1 }}
            onClick={() => {
              const clipboardItem = new ClipboardItem({
                "text/plain": new Blob([content], { type: "text/plain" }),
              });

              navigator.clipboard.write([clipboardItem]);

              if (timerID.current) {
                clearTimeout(timerID.current);
              }

              setIsCopied(true);

              timerID.current = setTimeout(() => {
                setIsCopied(false);
              }, 3000);
            }}
          />
        </Tooltip>
      )}
    </Box>
  );
};

export default InfoItem;
