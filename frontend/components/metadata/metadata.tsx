import { useState } from "react";
import { useParams } from "react-router-dom";
import { format } from "date-fns";
import { Principal } from "@dfinity/principal";
import {
  Box,
  Tabs,
  TabList,
  Tab,
  Button,
  LinearProgress,
  Typography,
} from "@mui/joy";

import { useGetCanisterMetadata } from "@fe/integration";
import DashboardPageLayout from "@fe/components/dashboard-page-layout";

import CanisterMetadata from "./canister-metadata";
import WasmMetadata from "./wasm-metadata";
import UpdateMetadataModal from "./update-metadata-modal";

interface MetadataProps {
  callerIsController: boolean;
}

const Metadata = ({ callerIsController }: MetadataProps) => {
  const { canisterId } = useParams();

  const [tabValue, setTabValue] = useState(0);

  const [modalIsOpen, setModalIsOpen] = useState(false);
  const openModal = () => setModalIsOpen(true);
  const closeModal = () => setModalIsOpen(false);

  const { data, isFetching, refetch } = useGetCanisterMetadata(
    Principal.fromText(canisterId!)
  );

  return (
    <DashboardPageLayout
      title="Metadata"
      rightPart={
        callerIsController ? (
          <Button
            onClick={openModal}
            variant="outlined"
            size="sm"
            color="neutral"
          >
            Update metadata
          </Button>
        ) : undefined
      }
      onRefetch={() => {
        refetch();
      }}
      isFetching={isFetching}
    >
      {isFetching ? (
        <LinearProgress sx={{ marginY: 1 }} />
      ) : !data ? (
        "Something went wrong"
      ) : (
        <Box>
          <Typography sx={{ marginBottom: 1 }} level="body-sm">
            Latest update:{" "}
            {data.latest_update_timestamp > 0
              ? format(
                  new Date(Number(data.latest_update_timestamp) / 1_000_000),
                  "MMM dd, yyyy HH:mm"
                )
              : "Not updated"}
          </Typography>
          <Tabs
            sx={{ backgroundColor: "transparent" }}
            value={tabValue}
            onChange={(_, value) => setTabValue(value as number)}
          >
            <TabList
              sx={{ flexGrow: 1, marginBottom: 1 }}
              variant="plain"
              size="sm"
            >
              <Tab color="neutral">Canister</Tab>
              <Tab color="neutral">Wasm modules</Tab>
            </TabList>
          </Tabs>
          {tabValue === 0 && <CanisterMetadata data={data} />}
          {tabValue === 1 && (
            <WasmMetadata
              canisterId={Principal.fromText(canisterId!)}
              data={data}
              callerIsController={callerIsController}
            />
          )}
          <UpdateMetadataModal
            canisterId={Principal.fromText(canisterId!)}
            metadata={data}
            isOpen={modalIsOpen}
            onClose={closeModal}
          />
        </Box>
      )}
    </DashboardPageLayout>
  );
};

export default Metadata;
