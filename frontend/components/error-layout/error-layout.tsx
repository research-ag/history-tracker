import { Box, Button, Typography } from "@mui/joy";
import { Link } from "react-router-dom";

interface ErrorLayoutProps {
  message: string;
}

const ErrorLayout = ({ message }: ErrorLayoutProps) => {
  return (
    <Box
      sx={{
        width: "100%",
        maxWidth: "990px",
        p: 4,
        mx: "auto",
      }}
    >
      <Typography level="h3" color="danger">
        Error occurred
      </Typography>
      <Typography sx={{ marginBottom: 2 }} level="body-md">
        {message}
      </Typography>
      <Link to="/">
        <Button size="sm" color="neutral">
          Home page
        </Button>
      </Link>
    </Box>
  );
};

export default ErrorLayout;
