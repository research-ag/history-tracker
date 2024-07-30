import { useMutation, useQuery } from "react-query";
import { useSnackbar } from "notistack";
import { Principal } from "@dfinity/principal";

import { canisterId, createActor } from "@declarations/history_be";
import { _SERVICE } from "@declarations/history_be/history_be.did";

export const BACKEND_CANISTER_ID = canisterId;

export const useHistoryBackend = () => {
  const backend = createActor(canisterId);
  return { backend };
};

export const useGetIsCanisterTracked = (
  canisterId: Principal,
  enabled: boolean
) => {
  const { backend } = useHistoryBackend();
  return useQuery(
    ["is-canister-tracked", canisterId.toString()],
    () => backend.is_canister_tracked(canisterId),
    { enabled, staleTime: 0 }
  );
};

export const useTrack = () => {
  const { backend } = useHistoryBackend();
  const { enqueueSnackbar } = useSnackbar();
  return useMutation((canisterId: Principal) => backend.track(canisterId), {
    onSuccess: () => {
      enqueueSnackbar("The canister has been successfully registered", {
        variant: "success",
      });
    },
    onError: () => {
      enqueueSnackbar("Failed to register the canister", {
        variant: "error",
      });
    },
  });
};

export const useGetCanisterChanges = (canisterId: Principal) => {
  const { backend } = useHistoryBackend();
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    ["canister-changes", canisterId.toString()],
    () => backend.canister_changes(canisterId),
    {
      onError: () => {
        enqueueSnackbar("Failed to fetch the canister changes", {
          variant: "error",
        });
      },
    }
  );
};

export const useGetCanisterState = (canisterId: Principal) => {
  const { backend } = useHistoryBackend();
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    ["canister-state", canisterId.toString()],
    () => backend.canister_state(canisterId),
    {
      onError: () => {
        enqueueSnackbar("Failed to fetch the canister state", {
          variant: "error",
        });
      },
    }
  );
};
