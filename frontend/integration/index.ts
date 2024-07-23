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

  return useQuery("canister-id", () => backend.canisterId(), {
    onError: () => {
      enqueueSnackbar("Failed to fetch canister id", { variant: "error" });
    },
  });
};

export const useGetCanisterInfo = () => {
  const { backend } = useHistoryBackend();

  const { enqueueSnackbar } = useSnackbar();

  return useQuery("canister-info", () => backend.canisterInfo(), {
    onError: () => {
      enqueueSnackbar("Failed to fetch canister info", { variant: "error" });
    },
  });
};
