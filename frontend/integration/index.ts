import { useMemo } from "react";
import { useMutation, useQuery, useQueryClient } from "react-query";
import { useSnackbar } from "notistack";

import { canisterId, createActor } from "@declarations/history_be";
import { _SERVICE } from "@declarations/history_be/history_be.did";

export const BACKEND_CANISTER_ID = canisterId;

export const useHistoryBackend = () => {
  const backend = createActor(canisterId);
  return { backend };
};

export const useGetCanisterId = () => {
  const { backend } = useHistoryBackend();

  const { enqueueSnackbar } = useSnackbar();

  return useQuery("canister-id", () => backend.canister_id(), {
    onError: () => {
      enqueueSnackbar("Failed to fetch the canister ID", { variant: "error" });
    },
  });
};

export const useGetCanisterChanges = () => {
  const { backend } = useHistoryBackend();

  const { enqueueSnackbar } = useSnackbar();

  return useQuery("canister-changes", () => backend.canister_changes(), {
    onError: () => {
      enqueueSnackbar("Failed to fetch the canister changes", {
        variant: "error",
      });
    },
  });
};

export const useGetCanisterState = () => {
  const { backend } = useHistoryBackend();

  const { enqueueSnackbar } = useSnackbar();

  return useQuery("canister-state", () => backend.canister_state(), {
    onError: () => {
      enqueueSnackbar("Failed to fetch the canister state", {
        variant: "error",
      });
    },
  });
};
