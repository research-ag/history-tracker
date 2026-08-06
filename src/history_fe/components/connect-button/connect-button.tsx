import { useLayoutEffect, useState } from "react";
import { AuthClient } from "@icp-sdk/auth/client";
import { safeGetCanisterEnv } from "@icp-sdk/core/agent/canister-env";
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

const isMainnet = () =>
  !["localhost", "127.0.0.1"].includes(window.location.hostname);

const getIdentityProvider = () =>
  isMainnet()
    ? "https://identity.ic0.app/#authorize"
    : `http://${safeGetCanisterEnv()?.["PUBLIC_CANISTER_ID:internet_identity"]}.localhost:8000/#authorize`;

const createAuthClient = () =>
  new AuthClient({
    identityProvider: getIdentityProvider(),
    derivationOrigin: isMainnet()
      ? "https://wugbx-viaaa-aaaao-a3rcq-cai.icp0.io"
      : undefined,
    windowOpenerFeatures:
      `left=${window.screen.width / 2 - 525 / 2}, ` +
      `top=${window.screen.height / 2 - 705 / 2},` +
      `toolbar=0,location=0,menubar=0,width=525,height=705`,
  });

const ConnectButton = ({ sx, iconButtonOnMobile }: ConnectButtonProps) => {
  const theme = useTheme();

  const downSm = useMediaQuery(theme.breakpoints.down("sm"));

  const [authClient, setAuthClient] = useState<AuthClient | null>(null);

  const { identity, setIdentity } = useIdentity();

  const isConnected = identity.getPrincipal().toText() !== "2vxsx-fae";

  const isIconButton = iconButtonOnMobile && downSm;

  useLayoutEffect(() => {
    const client = createAuthClient();
    setAuthClient(client);
    client.getIdentity().then(setIdentity);
  }, []);

  const handleConnect = async () => {
    if (!authClient) {
      return;
    }

    const identity = await authClient.signIn({
      maxTimeToLive: BigInt(30) * BigInt(3_600_000_000_000),
    });
    setIdentity(identity);
  };

  const handleDisconnect = async () => {
    if (!authClient) {
      return;
    }

    await authClient.signOut();
    const identity = await authClient.getIdentity();
    setIdentity(identity);
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
