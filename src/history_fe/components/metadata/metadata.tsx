import { useState } from "react";
import { useParams } from "react-router-dom";
import { format } from "date-fns";
import { Principal } from "@icp-sdk/core/principal";
import { Box, Button, LinearProgress, Typography, useTheme } from "@mui/joy";
import { useMediaQuery } from "@mui/material"; // TODO: @mui/material should not be used. Temporary solution.

import { useGetCanisterMetadata } from "@fe/integration";
import DashboardPageLayout from "@fe/components/dashboard-page-layout";
import MetadataSourcesModal from "@fe/components/metadata-sources-modal";

import UpdateMetadataModal from "./update-metadata-modal";

interface MetadataProps {
  callerIsController: boolean;
}

const Metadata = ({ callerIsController }: MetadataProps) => {
  const theme = useTheme();

  const down650 = useMediaQuery(theme.breakpoints.down(650));

  const { canisterId } = useParams();

  const [modalIsOpen, setModalIsOpen] = useState(false);
  const openModal = () => setModalIsOpen(true);
  const closeModal = () => setModalIsOpen(false);

  const { data, isFetching, refetch } = useGetCanisterMetadata(
    Principal.fromText(canisterId!)
  );

  const [metadataSourcesModalOpen, setMetadataSourcesModalOpen] =
    useState(false);

  const buttons = (
    <Box
      sx={{
        display: "flex",
        flexWrap: "wrap",
        gap: 1,

        ...(down650 && {
          marginBottom: 1,
        }),
      }}
    >
      <Button
        sx={{
          ...(down650 && {
            flex: 1,
            whiteSpace: "nowrap",
          }),
        }}
        onClick={() => setMetadataSourcesModalOpen(true)}
        variant="outlined"
        size="sm"
        color="neutral"
      >
        Metadata sources
      </Button>
      {callerIsController ? (
        <Button
          sx={{
            ...(down650 && {
              flex: 1,
              whiteSpace: "nowrap",
            }),
          }}
          onClick={openModal}
          variant="outlined"
          size="sm"
          color="neutral"
        >
          Update metadata
        </Button>
      ) : undefined}
    </Box>
  );

  return (
    <DashboardPageLayout
      title="Metadata"
      rightPart={!down650 ? buttons : null}
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
          {down650 && buttons}
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
          <MetadataSourcesModal
            isOpen={metadataSourcesModalOpen}
            onClose={() => setMetadataSourcesModalOpen(false)}
          />
        </Box>
      )}
    </DashboardPageLayout>
  );
};

export default Metadata;
