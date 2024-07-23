import { IconButton, useColorScheme } from "@mui/joy";
import { SxProps } from "@mui/joy/styles/types";
import LightModeIcon from "@mui/icons-material/LightMode";
import DarkModeIcon from "@mui/icons-material/DarkMode";

interface ThemeButtonProps {
  sx?: SxProps;
}

const ThemeButton = ({ sx }: ThemeButtonProps) => {
  const { mode, setMode } = useColorScheme();

  return (
    <IconButton
      sx={sx}
      variant="outlined"
      color="neutral"
      onClick={() => setMode(mode === "dark" ? "light" : "dark")}
    >
      {mode === "dark" ? <LightModeIcon /> : <DarkModeIcon />}
    </IconButton>
  );
};

export default ThemeButton;
