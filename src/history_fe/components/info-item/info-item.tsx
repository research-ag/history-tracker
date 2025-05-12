import { useRef, useState } from "react";
import { Box, Typography, Tooltip } from "@mui/joy";
import ContentCopyIcon from "@mui/icons-material/ContentCopy";

interface InfoItemProps {
  label: string;
  content: string;
  withCopy?: boolean;
  copyAlwaysLeft?: boolean; // workaround
}

const InfoItem = ({
  label,
  content,
  withCopy,
  copyAlwaysLeft,
}: InfoItemProps) => {
  const timerID = useRef<NodeJS.Timeout | null>(null);

  const [isCopied, setIsCopied] = useState(false);

  const copyTooltipTitle = isCopied ? "✓ Copied" : "Copy to clipboard";

  return (
    <Box sx={{ display: "flex", alignItems: "flex-start", gap: 1 }}>
      <Typography sx={{ order: 1 }} level="body-xs">
        <Box sx={{ fontWeight: 700 }} component="span">
          {label}
        </Box>
        : {content}
      </Typography>
      {withCopy && (
        <Tooltip title={copyTooltipTitle} disableInteractive>
          <ContentCopyIcon
            sx={(theme) => ({
              order: 2,
              fontSize: "16px",
              cursor: "pointer",
              marginTop: "1px",
              [theme.breakpoints.down("sm")]: {
                order: 0,
              },
              ...(copyAlwaysLeft && { order: 0 }),
            })}
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
