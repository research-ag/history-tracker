import { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import { Principal } from "@dfinity/principal";
import { Box, Tabs, TabList, Tab, Button, Typography } from "@mui/joy";
import HomeIcon from "@mui/icons-material/Home";

import Changes from "@fe/components/changes";
import CurrentState from "@fe/components/current-state";
import Metadata from "@fe/components/metadata";
import Manage from "@fe/components/manage";
import ConnectButton from "@fe/components/connect-button";
import ThemeButton from "@fe/components/theme-button";
import LoadingPage from "@fe/components/loading-page";
import ErrorLayout from "@fe/components/error-layout";
import { useIdentity } from "@fe/integration/identity";
import {
  useGetIsCanisterTracked,
  useCallerIsController,
} from "@fe/integration";

import InfoItem from "./info-item";

const Dashboard = () => {
  const [tabValue, setTabValue] = useState(0);

  const { identity } = useIdentity();

  const userPrincipal = identity.getPrincipal().toText();

  const { canisterId } = useParams();

  const { canisterId_, isCanisterIdValid } = (() => {
    try {
      return {
        canisterId_: Principal.fromText(canisterId!),
        isCanisterIdValid: true,
      };
    } catch (_) {
      return { canisterId_: Principal.anonymous(), isCanisterIdValid: false };
    }
  })();

  const {
    data: isCanisterTracked,
    isLoading: isCanisterTrackedLoading,
    remove: removeIsCanisterTracked,
  } = useGetIsCanisterTracked(canisterId_, isCanisterIdValid);

  const { data: callerIsController, remove: removeCallerIsController } =
    useCallerIsController(canisterId_, isCanisterTracked ?? false);

  useEffect(() => {
    return () => {
      removeIsCanisterTracked();
      removeCallerIsController();
    };
  }, [removeIsCanisterTracked, removeCallerIsController]);

  if (isCanisterTrackedLoading) {
    return <LoadingPage />;
  }

  if (!isCanisterIdValid) {
    return <ErrorLayout message="The canister ID is not valid." />;
  }

  if (!isCanisterTracked) {
    return <ErrorLayout message="The canister is not tracked." />;
  }

  return (
    <Box
      sx={{
        width: "100%",
        maxWidth: "990px",
        p: 4,
        mx: "auto",
      }}
    >
      <Tabs
        sx={{ backgroundColor: "transparent" }}
        value={tabValue}
        onChange={(_, value) => setTabValue(value as number)}
      >
        <Box sx={{ display: "flex", justifyContent: "flex-end" }}>
          <Box
            sx={{
              display: "flex",
              flexDirection: "column",
              alignItems: "flex-end",
              gap: 0.5,
              marginBottom: 1,
            }}
          >
            {callerIsController && (
              <Typography
                sx={{ fontWeight: 700 }}
                color="success"
                level="body-xs"
              >
                You are a controller
              </Typography>
            )}
            <InfoItem label="Your principal" content={userPrincipal} withCopy />
            <InfoItem
              label="Watched canister ID"
              content={canisterId!}
              withCopy
            />
          </Box>
        </Box>
        <Box
          sx={{
            display: "flex",
            alignItems: "center",
            marginBottom: 2,
          }}
        >
          <TabList sx={{ flexGrow: 1 }} variant="plain">
            <Tab color="neutral">Canister changes</Tab>
            <Tab color="neutral">Current state</Tab>
            <Tab color="neutral">Metadata</Tab>
            <Tab color="neutral">Manage</Tab>
          </TabList>
          <Link to="/">
            <Button
              sx={{ marginLeft: 1 }}
              variant="solid"
              color="primary"
              startDecorator={<HomeIcon />}
            >
              Home
            </Button>
          </Link>
          <ConnectButton sx={{ marginLeft: 1 }} />
          <ThemeButton sx={{ marginLeft: 1 }} />
        </Box>
        {tabValue === 0 && <Changes />}
        {tabValue === 1 && <CurrentState />}
        {tabValue === 2 && (
          <Metadata callerIsController={callerIsController ?? false} />
        )}
        {tabValue === 3 && (
          <Manage callerIsController={callerIsController ?? false} />
        )}
      </Tabs>
    </Box>
  );
};

export default Dashboard;
