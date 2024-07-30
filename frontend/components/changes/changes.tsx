import { useParams } from "react-router-dom";
import { parseISO, format } from "date-fns";
import { Principal } from "@dfinity/principal";
import {
  Box,
  Divider,
  LinearProgress,
  Table,
  Typography,
  useTheme,
} from "@mui/joy";
import { SHA256, enc } from "crypto-js";

import DashboardPageLayout from "@fe/components/dashboard-page-layout";
import { useGetCanisterChanges } from "@fe/integration";
import { ExtendedChange } from "@declarations/history_be/history_be.did";

import ItemWithDetails from "./item-with-details";

const Changes = () => {
  const theme = useTheme();

  const { canisterId } = useParams();

  const { data, isLoading } = useGetCanisterChanges(
    Principal.fromText(canisterId!)
  );

  const isCorrupted = !!data?.corruption_timestamp?.[0];

  const renderAction = (change: ExtendedChange): React.ReactNode => {
    if ("creation" in change.details)
      return (
        <ItemWithDetails
          title="Creation"
          details={
            <Box sx={{ overflowWrap: "break-word" }}>
              <Box sx={{ fontWeight: 600 }}>Controllers:</Box>
              <Box component="ul">
                {change.details.creation.controllers.map((c, i) => (
                  <Box key={i} component="li">
                    {c.toText()}
                  </Box>
                ))}
              </Box>
            </Box>
          }
        />
      );
    if ("code_deployment" in change.details) {
      const codeDeploymentRecord = change.details.code_deployment;
      const getMode = () => {
        if ("reinstall" in codeDeploymentRecord.mode) return "Reinstall";
        if ("upgrade" in codeDeploymentRecord.mode) return "Upgrade";
        if ("install" in codeDeploymentRecord.mode) return "Install";
      };
      const getModuleHash = () => {
        const hash = SHA256(codeDeploymentRecord.module_hash.join(","));
        return hash.toString(enc.Hex);
      };
      return (
        <ItemWithDetails
          title="Code deployment"
          details={
            <Box sx={{ overflowWrap: "break-word" }}>
              <Box>
                <Box sx={{ display: "inline", fontWeight: 600 }}>Mode:</Box>{" "}
                {getMode()}
              </Box>
              <Box>
                <Box
                  sx={{
                    display: "inline",
                    fontWeight: 600,
                  }}
                >
                  Module hash:
                </Box>{" "}
                {getModuleHash()}
              </Box>
            </Box>
          }
        />
      );
    }
    if ("controllers_change" in change.details)
      return (
        <ItemWithDetails
          title="Controllers change"
          details={
            <Box sx={{ overflowWrap: "break-word" }}>
              <Box sx={{ fontWeight: 600 }}>Controllers:</Box>
              <Box component="ul">
                {change.details.controllers_change.controllers.map((c, i) => (
                  <Box key={i} component="li">
                    {c.toText()}
                  </Box>
                ))}
              </Box>
            </Box>
          }
        />
      );
    if ("code_uninstall" in change.details) return "Code uninstall";
  };

  const renderOrigin = (change: ExtendedChange): React.ReactNode => {
    if ("from_user" in change.origin)
      return (
        <ItemWithDetails
          title="From user"
          details={
            <Box sx={{ overflowWrap: "break-word" }}>
              <Box
                sx={{
                  display: "inline",
                  fontWeight: 600,
                }}
              >
                Principal:
              </Box>{" "}
              {change.origin.from_user.user_id.toString()}
            </Box>
          }
        />
      );
    if ("from_canister" in change.origin)
      return (
        <ItemWithDetails
          title="From canister"
          details={
            <Box>
              <Box sx={{ overflowWrap: "break-word" }}>
                <Box
                  sx={{
                    display: "inline",
                    fontWeight: 600,
                  }}
                >
                  Canister ID:
                </Box>{" "}
                {change.origin.from_canister.canister_id.toString()}
              </Box>
              <Box sx={{ overflowWrap: "break-word" }}>
                <Box
                  sx={{
                    display: "inline",
                    fontWeight: 600,
                  }}
                >
                  Canister version:
                </Box>{" "}
                {change.origin.from_canister.canister_version.length
                  ? Number(change.origin.from_canister.canister_version[0])
                  : "N/A"}
              </Box>
            </Box>
          }
        />
      );
  };

  const addGaps = (
    changes: Array<ExtendedChange>
  ): Array<ExtendedChange | number> => {
    if (changes.length < 2) {
      return changes;
    }

    let changesWithGaps: Array<ExtendedChange | number> = [];

    changesWithGaps.push(changes[0]);

    for (let i = 1; i < changes.length; i++) {
      const prev = changes[i - 1];
      const cur = changes[i];

      let delta = Math.abs(
        Number(cur.change_index) - Number(prev.change_index)
      );

      if (delta !== 1) {
        changesWithGaps.push(delta - 1);
      }

      changesWithGaps.push(cur);
    }

    return changesWithGaps;
  };

  return (
    <DashboardPageLayout
      title="Changelog"
      noteTooltip={
        <Box sx={{ width: "400px" }}>
          <Box sx={{ marginBottom: 1 }}>
            Please be aware that the history of a canister on the Internet
            Computer can only be recorded and accessed from the moment the
            feature enabling canister history tracking was released. This
            feature was officially launched on{" "}
            {format(parseISO("2023-06-05T09:47:46Z"), "MMM dd, yyyy HH:mm")}.
          </Box>
          <Box>
            Any actions or events involving canisters prior to this date will
            not be included in the historical records. We appreciate your
            understanding and encourage you to take this into consideration when
            reviewing canister activities and logs.
          </Box>
        </Box>
      }
    >
      <Box sx={{ width: "100%", overflow: "auto" }}>
        {isLoading ? (
          <LinearProgress sx={{ marginY: 1 }} />
        ) : !data ? (
          "Something went wrong"
        ) : (
          <>
            <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
              <Typography
                sx={{ fontWeight: 600, textTransform: "uppercase" }}
                level="body-xs"
                color={isCorrupted ? "danger" : "success"}
              >
                {isCorrupted ? "Corrupted" : "Not corrupted"}
              </Typography>
              <Divider orientation="vertical" />
              <Typography level="body-xs">
                Total records: {Number(data.total_num_changes)}
              </Typography>
              <Divider orientation="vertical" />
              <Typography level="body-xs">
                Tracked records: {data.changes.length}
              </Typography>
              <Divider orientation="vertical" />
              <Typography level="body-xs">
                History completeness:{" "}
                {data.total_num_changes > 0
                  ? `${(
                      (data.changes.length / Number(data.total_num_changes)) *
                      100
                    ).toFixed(2)}%`
                  : "N/A"}
              </Typography>
              <Divider orientation="vertical" />
              <Typography level="body-xs">
                Latest sync:{" "}
                {data.timestamp_nanos > 0
                  ? format(
                      new Date(Number(data.timestamp_nanos) / 1_000_000),
                      "MMM dd, yyyy HH:mm"
                    )
                  : "N/A"}
              </Typography>
            </Box>
            <Table sx={{ "& tr": { height: "45px" } }}>
              <colgroup>
                <col style={{ width: "80px" }} />
                <col style={{ width: "100px" }} />
                <col />
                <col />
                <col style={{ width: "180px" }} />
              </colgroup>

              <thead>
                <tr>
                  <th>Index</th>
                  <th>Version</th>
                  <th>Action</th>
                  <th>Origin</th>
                  <th>Date</th>
                </tr>
              </thead>
              <tbody>
                {addGaps([...data.changes].reverse()).map((change, i) => {
                  if (typeof change == "number") {
                    return (
                      <tr
                        style={{ background: theme.palette.warning[50] }}
                        key={i}
                      >
                        <td colSpan={5}>
                          <Box
                            sx={{
                              display: "flex",
                              alignItems: "center",
                              gap: 2,
                            }}
                          >
                            <Typography
                              sx={{ display: "inline", fontWeight: 600 }}
                              color="warning"
                            >
                              WARNING
                            </Typography>
                            <Typography>
                              Gap of{" "}
                              <Typography
                                sx={{ display: "inline", fontWeight: 600 }}
                              >
                                {change}
                              </Typography>{" "}
                              change
                              {change > 1 ? "s" : ""}
                            </Typography>
                          </Box>
                        </td>
                      </tr>
                    );
                  }

                  return (
                    <tr key={change.timestamp_nanos}>
                      <td>{Number(change.change_index)}</td>
                      <td>{Number(change.canister_version)}</td>
                      <td>{renderAction(change)}</td>
                      <td>{renderOrigin(change)}</td>
                      <td>
                        {format(
                          new Date(Number(change.timestamp_nanos) / 1_000_000),
                          "MMM dd, yyyy HH:mm"
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </Table>
          </>
        )}
      </Box>
    </DashboardPageLayout>
  );
};

export default Changes;
