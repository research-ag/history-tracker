import { Sheet, Box, Typography, Tooltip } from "@mui/joy";
import InfoIcon from "@mui/icons-material/Info";

interface PageTemplateProps {
  children: React.ReactNode;
  title: string;
  noteTooltip?: React.ReactNode;
}

const PageTemplate = ({ children, title, noteTooltip }: PageTemplateProps) => {
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
      </Box>
      {children}
    </Sheet>
  );
};

export default PageTemplate;
