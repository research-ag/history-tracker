import { useEffect, useLayoutEffect, useState } from "react";
import { AuthClient } from "@dfinity/auth-client";
import { Button, IconButton, useTheme } from "@mui/joy";
import { SxProps } from "@mui/joy/styles/types";
import { useMediaQuery } from "@mui/material"; // TODO: @mui/material should not be used. Temporary solution.
import LoginIcon from "@mui/icons-material/Login";
import LogoutIcon from "@mui/icons-material/Logout";

import { useIdentity } from "@fe/integration/identity";

interface ConnectButtonProps {
  sx?: SxProps;
  iconButtonOnMobile?: boolean;
}

const ConnectButton = ({ sx, iconButtonOnMobile }: ConnectButtonProps) => {
  const theme = useTheme();

  const downSm = useMediaQuery(theme.breakpoints.down("sm"));

  const [authClient, setAuthClient] = useState<AuthClient | null>(null);

  const { identity, setIdentity } = useIdentity();

  const isConnected = identity.getPrincipal().toText() !== "2vxsx-fae";

  const isIconButton = iconButtonOnMobile && downSm;

  useLayoutEffect(() => {
    AuthClient.create().then(setAuthClient);
  }, []);

  useEffect(() => {
    if (authClient) {
      const identity = authClient.getIdentity();
      setIdentity(identity);
    }
  }, [authClient]);

  const handleConnect = () => {
    if (!authClient) {
      return;
    }

    authClient.login({
      onSuccess: () => {
        const identity = authClient.getIdentity();
        setIdentity(identity);
      },
      derivationOrigin:
        process.env.DFX_NETWORK === "ic"
          ? "https://wugbx-viaaa-aaaao-a3rcq-cai.icp0.io"
          : undefined,
      maxTimeToLive: BigInt(30) * BigInt(3_600_000_000_000),
      identityProvider:
        process.env.DFX_NETWORK === "ic" ||
        process.env.DFX_NETWORK === "playground"
          ? "https://identity.ic0.app/#authorize"
          : `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943/#authorize`,
      windowOpenerFeatures:
        `left=${window.screen.width / 2 - 525 / 2}, ` +
        `top=${window.screen.height / 2 - 705 / 2},` +
        `toolbar=0,location=0,menubar=0,width=525,height=705`,
    });
  };

  const handleDisconnect = () => {
    if (!authClient) {
      return;
    }

    authClient.logout().then(() => {
      const identity = authClient.getIdentity();
      setIdentity(identity);
    });
  };

  return !isIconButton ? (
    <Button
      sx={sx}
      onClick={!isConnected ? handleConnect : handleDisconnect}
      color={!isConnected ? "success" : "danger"}
    >
      {!isConnected ? "Connect" : "Disconnect"}
    </Button>
  ) : (
    <IconButton
      sx={sx}
      variant="solid"
      color={!isConnected ? "success" : "danger"}
      onClick={!isConnected ? handleConnect : handleDisconnect}
    >
      {!isConnected ? <LoginIcon /> : <LogoutIcon />}
    </IconButton>
  );
};

export default ConnectButton;
