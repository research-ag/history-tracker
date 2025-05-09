import { useEffect } from "react";
import { useParams, Link } from "react-router-dom";
import { Principal } from "@dfinity/principal";
import {
  Box,
  Tabs,
  TabList,
  Tab,
  Button,
  Typography,
  Select,
  Option,
  useTheme,
} from "@mui/joy";
import { useMediaQuery } from "@mui/material"; // TODO: @mui/material should not be used. Temporary solution.
import HomeIcon from "@mui/icons-material/Home";

import Changes from "@fe/components/changes";
import CurrentState from "@fe/components/current-state";
import Metadata from "@fe/components/metadata";
import Manage from "@fe/components/manage";
import ConnectButton from "@fe/components/connect-button";
import ThemeButton from "@fe/components/theme-button";
import LoadingPage from "@fe/components/loading-page";
import ErrorLayout from "@fe/components/error-layout";
import InfoItem from "@fe/components/info-item";
import { useIdentity } from "@fe/integration/identity";
import {
  BACKEND_CANISTER_ID,
  METADATA_DIRECTORY_BACKEND_CANISTER_ID,
  useGetIsCanisterTracked,
  useCallerIsController,
  useCanisterStatus,
} from "@fe/integration";

import { useTabManagement } from "./tabs-management";

const Dashboard = () => {
  const theme = useTheme();

  const downMd = useMediaQuery(theme.breakpoints.down("md"));

  const { tabValue, setTabValue } = useTabManagement();

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

  const { callerIsController } = useCallerIsController(
    canisterId_,
    isCanisterTracked ?? false
  );

  useCanisterStatus(canisterId_, callerIsController ?? false);

  useEffect(() => {
    return () => {
      removeIsCanisterTracked();
    };
  }, [removeIsCanisterTracked]);

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
        <Box
          sx={(theme) => ({
            display: "flex",
            justifyContent: "flex-end",

            [theme.breakpoints.down("sm")]: {
              justifyContent: "flex-start",
            },
          })}
        >
          <Box
            sx={(theme) => ({
              display: "flex",
              flexDirection: "column",
              alignItems: "flex-end",
              gap: 0.5,
              marginBottom: 1,

              [theme.breakpoints.down("sm")]: {
                alignItems: "flex-start",
                marginBottom: 2,
              },
            })}
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
              label="Backend canister ID"
              content={BACKEND_CANISTER_ID}
              withCopy
            />
            <InfoItem
              label="MD backend canister ID"
              content={METADATA_DIRECTORY_BACKEND_CANISTER_ID}
              withCopy
            />
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
            gap: 1,
            flexWrap: "wrap",
            marginBottom: 2,
          }}
        >
          {!downMd ? (
            <TabList sx={{ flexGrow: 1 }} variant="plain">
              <Tab color="neutral">Canister changes</Tab>
              <Tab color="neutral">Current state</Tab>
              <Tab color="neutral">Metadata</Tab>
              <Tab color="neutral">Management</Tab>
            </TabList>
          ) : (
            <Select
              sx={(theme) => ({
                flexShrink: "0",
                width: "200px",
                mr: "auto",

                [theme.breakpoints.down("sm")]: {
                  width: "100%",
                },
              })}
              value={String(tabValue)}
              onChange={(_, value) => setTabValue(Number(value))}
            >
              <Option value="0">Canister changes</Option>
              <Option value="1">Current state</Option>
              <Option value="2">Metadata</Option>
              <Option value="3">Management</Option>
            </Select>
          )}
          <Link style={{ display: "contents" }} to="/">
            <Button
              sx={(theme) => ({
                [theme.breakpoints.down("sm")]: {
                  flex: "1",
                },
              })}
              variant="solid"
              color="primary"
              startDecorator={<HomeIcon />}
            >
              Home
            </Button>
          </Link>
          <ConnectButton
            sx={(theme) => ({
              [theme.breakpoints.down("sm")]: {
                flex: "1",
              },
            })}
          />
          <ThemeButton />
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
