import { Box } from "@mui/joy";

interface BlocksContainerProps {
  children: React.ReactNode;
}

const BlocksContainer = ({ children }: BlocksContainerProps) => {
  return (
    <Box
      sx={(theme) => ({
        display: "flex",
        flexWrap: "wrap",
        width: `calc(100% + ${theme.spacing(2)})`,
        m: `0 -${theme.spacing(1)}`,
      })}
    >
      {children}
    </Box>
  );
};

export default BlocksContainer;
