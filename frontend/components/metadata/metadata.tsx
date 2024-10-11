import { useState } from "react";
import { useParams } from "react-router-dom";
import { format } from "date-fns";
import { Principal } from "@dfinity/principal";
import { Box, Button, LinearProgress, Typography } from "@mui/joy";

import { useGetCanisterMetadata } from "@fe/integration";
import DashboardPageLayout from "@fe/components/dashboard-page-layout";

import UpdateMetadataModal from "./update-metadata-modal";

interface MetadataProps {
  callerIsController: boolean;
}

const Metadata = ({ callerIsController }: MetadataProps) => {
  const { canisterId } = useParams();

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
          <Box sx={{ marginBottom: 1 }}>
            <Box sx={{ display: "inline", fontWeight: 600 }}>Name:</Box>{" "}
            <Box sx={{ display: "inline" }}>{data.name}</Box>
          </Box>
          <Box>
            <Box sx={{ display: "inline", fontWeight: 600 }}>Description:</Box>{" "}
            <Box sx={{ display: "inline" }}>{data.description}</Box>
          </Box>
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
