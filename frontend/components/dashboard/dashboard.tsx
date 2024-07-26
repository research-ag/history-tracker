import { useState } from "react";
import { useParams, Link } from "react-router-dom";
import { Principal } from "@dfinity/principal";
import { Box, Tabs, TabList, Tab, Button } from "@mui/joy";
import HomeIcon from "@mui/icons-material/Home";

import Changes from "@fe/components/changes";
import CurrentState from "@fe/components/current-state";
import ThemeButton from "@fe/components/theme-button";
import { useGetIsCanisterTracked } from "@fe/integration";
import LoadingPage from "@fe/components/loading-page";
import ErrorLayout from "@fe/components/error-layout";

import InfoItem from "./info-item";

const Dashboard = () => {
  const [tabValue, setTabValue] = useState(0);

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

  const { data: isCanisterTracked, isLoading: isCanisterTrackedLoading } =
    useGetIsCanisterTracked(canisterId_, isCanisterIdValid);

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
          <ThemeButton sx={{ marginLeft: 1 }} />
        </Box>
        {tabValue === 0 && <Changes />}
        {tabValue === 1 && <CurrentState />}
      </Tabs>
    </Box>
  );
};

export default Dashboard;
