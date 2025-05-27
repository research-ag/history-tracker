import { Box } from "@mui/joy";

interface BlockBaseProps {
  children: React.ReactNode;
}

const BlockBase = ({ children }: BlockBaseProps) => {
  return (
    <Box
      sx={(theme) => ({
        p: 1,
        width: "50%",
        minHeight: "250px",
        flexShrink: 0,

        [theme.breakpoints.down("sm")]: {
          width: "100%",
        },
      })}
    >
      <Box
        sx={(theme) => ({
          height: "100%",
          p: 3,
          backgroundColor: theme.palette.background.level1,
          borderRadius: "8px",
        })}
      >
        {children}
      </Box>
    </Box>
  );
};

export default BlockBase;
