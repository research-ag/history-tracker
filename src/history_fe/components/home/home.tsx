import { useState } from "react";
import { Box } from "@mui/joy";

import InfoItem from "@fe/components/info-item";
import { useIdentity } from "@fe/integration/identity";
import { BACKEND_CANISTER_ID } from "@fe/integration";
import MetadataSourcesModal from "@fe/components/metadata-sources-modal";

import Header from "./header";
import BlocksContainer from "./system/blocks-container";
import DashboardBlock from "./blocks/dashboard-block";
import StatsBlock from "./blocks/stats-block";
import TrackBlock from "./blocks/track-block";
import TrackModal from "./track-modal";
import TrackManyModal from "./track-many-modal";
import MetadataBlock from "./blocks/metadata-block";

const Home = () => {
  const [trackModalOpen, setTrackModalOpen] = useState(false);

  const [trackManyModalOpen, setTrackManyModalOpen] = useState(false);

  const [metadataSourcesModalOpen, setMetadataSourcesModalOpen] =
    useState(false);

  const { identity } = useIdentity();

  const userPrincipal = identity.getPrincipal().toText();

  return (
    <Box>
      <Header />
      <Box
        sx={{
          width: "100%",
          maxWidth: "990px",
          py: 3,
          px: 2,
          mx: "auto",
        }}
      >
        <Box
          sx={{
            display: "flex",
            flexDirection: "column",
            alignItems: "flex-start",
            gap: 0.5,
            marginBottom: 3,
          }}
        >
          <InfoItem
            label="Your principal"
            content={userPrincipal}
            withCopy
            copyAlwaysLeft
          />
          <InfoItem
            label="Backend canister ID"
            content={BACKEND_CANISTER_ID}
            withCopy
            copyAlwaysLeft
          />
        </Box>
        <BlocksContainer>
          <DashboardBlock />
          <StatsBlock />
          <TrackBlock
            onTrackOne={() => setTrackModalOpen(true)}
            onTrackMany={() => setTrackManyModalOpen(true)}
          />
          <MetadataBlock
            onMetadataSourcesClick={() => setMetadataSourcesModalOpen(true)}
          />
        </BlocksContainer>
      </Box>

      <TrackModal
        isOpen={trackModalOpen}
        onClose={() => setTrackModalOpen(false)}
      />
      <TrackManyModal
        isOpen={trackManyModalOpen}
        onClose={() => setTrackManyModalOpen(false)}
      />
      <MetadataSourcesModal
        isOpen={metadataSourcesModalOpen}
        onClose={() => setMetadataSourcesModalOpen(false)}
      />
    </Box>
  );
};

export default Home;
