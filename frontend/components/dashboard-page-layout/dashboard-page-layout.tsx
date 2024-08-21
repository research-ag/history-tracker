import { Sheet, Box, Typography, Tooltip, IconButton } from "@mui/joy";
import InfoIcon from "@mui/icons-material/Info";
import RefreshIcon from "@mui/icons-material/Refresh";

interface DashboardPageLayoutProps {
  children: React.ReactNode;
  title: string;
  rightPart?: React.ReactNode;
  noteTooltip?: React.ReactNode;
  onRefetch?: () => void;
  isFetching?: boolean;
}

const DashboardPageLayout = ({
  children,
  title,
  rightPart,
  noteTooltip,
  onRefetch,
  isFetching,
}: DashboardPageLayoutProps) => {
  return (
    <Sheet
      sx={{
        p: 2,
        display: "flex",
        flexDirection: "column",
        gap: 2,
        borderRadius: "sm",
        boxShadow: "md",
      }}
      variant="outlined"
      color="neutral"
    >
      <Box sx={{ display: "flex", alignItems: "center" }}>
        <Typography level="h1">{title}</Typography>
        {!!noteTooltip && (
          <Tooltip title={noteTooltip}>
            <InfoIcon sx={{ marginLeft: 2 }} />
          </Tooltip>
        )}
        {!!onRefetch && (
          <Tooltip title="Refresh page data">
            <IconButton sx={{ marginLeft: 0.5 }} disabled={isFetching}>
              <RefreshIcon onClick={onRefetch} />
            </IconButton>
          </Tooltip>
        )}
        <Box sx={{ marginLeft: "auto" }}>{rightPart}</Box>
      </Box>
      {children}
    </Sheet>
  );
};

export default DashboardPageLayout;
