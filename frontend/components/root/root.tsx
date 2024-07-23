import { useMemo, useState } from "react";
import { Box, Tabs, TabList, Tab } from "@mui/joy";

import Changes from "@fe/components/changes";
import CurrentState from "@fe/components/current-state";
import ThemeButton from "@fe/components/theme-button";
import { useGetCanisterId } from "@fe/integration";

import InfoItem from "./info-item";

const Root = () => {
  const [tabValue, setTabValue] = useState(0);

  const { data, isLoading } = useGetCanisterId();

  const watchedCanisterId = useMemo(() => {
    if (isLoading) return "Loading...";
    if (!data) return "N/A";
    return data.toString();
  }, [data]);

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
              content={watchedCanisterId}
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
          <ThemeButton sx={{ marginLeft: 1 }} />
        </Box>
        {tabValue === 0 && <Changes />}
        {tabValue === 1 && <CurrentState />}
      </Tabs>
    </Box>
  );
};

export default Root;
