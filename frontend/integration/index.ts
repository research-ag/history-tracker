import { useMutation, useQuery, useQueryClient } from "react-query";
import { useSnackbar } from "notistack";
import { Principal } from "@dfinity/principal";
import { ActorSubclass, Actor, HttpAgent } from "@dfinity/agent";

import { canisterId, createActor } from "@declarations/history_be";
import { _SERVICE } from "@declarations/history_be/history_be.did";

import { _SERVICE as MANAGEMENT_SERVICE } from "./management_idl/did";
import { idlFactory as managementIdlFactory } from "./management_idl/idl";
import { useIdentity } from "./identity";

export const BACKEND_CANISTER_ID = canisterId;
export const MANAGEMENT_CANISTER_ID = "aaaaa-aa";

export const useHistoryBackend = (() => {
  let backend: ActorSubclass<_SERVICE>;
  let prevIdentity: string;
  return () => {
    const { identity } = useIdentity();

    if (prevIdentity !== identity.getPrincipal().toText()) {
      backend = createActor(canisterId, {
        agentOptions: {
          identity,
          verifyQuerySignatures: false,
        },
      });
      prevIdentity = identity.getPrincipal().toText();
    }

    return { backend };
  };
})();

export const useManagementCanister = (() => {
  let management: ActorSubclass<MANAGEMENT_SERVICE>;
  let prevIdentity: string;
  return () => {
    const { identity } = useIdentity();

    if (prevIdentity !== identity.getPrincipal().toText()) {
      const agent = new HttpAgent({ identity, verifyQuerySignatures: false });
      management = Actor.createActor(managementIdlFactory, {
        canisterId: MANAGEMENT_CANISTER_ID,
        agent: agent,
      });
      agent.fetchRootKey().catch((err) => {
        console.warn(
          "Unable to fetch root key. Check to ensure that your local replica is running"
        );
        console.error(err);
      });
      prevIdentity = identity.getPrincipal().toText();
    }

    return { management };
  };
})();

export const useGetIsCanisterTracked = (
  canisterId: Principal,
  enabled: boolean
) => {
  const { backend } = useHistoryBackend();
  return useQuery(
    ["is-canister-tracked", canisterId.toString()],
    () => backend.is_canister_tracked(canisterId),
    { enabled }
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

export const useCallerIsController = (
  canisterId: Principal,
  enabled: boolean
) => {
  const { backend } = useHistoryBackend();
  const { identity } = useIdentity();
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    [
      "caller-is-controller",
      canisterId.toString(),
      identity.getPrincipal().toText(),
    ],
    () => backend.caller_is_controller(canisterId),
    {
      enabled,
      onError: () => {
        enqueueSnackbar(
          "Failed to check if the caller is a canister controller",
          {
            variant: "error",
          }
        );
      },
    }
  );
};

export const useGetCanisterMetadata = (canisterId: Principal) => {
  const { backend } = useHistoryBackend();
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    ["canister-metadata", canisterId.toString()],
    () => backend.metadata(canisterId),
    {
      onError: () => {
        enqueueSnackbar("Failed to fetch the canister metadata", {
          variant: "error",
        });
      },
    }
  );
};

interface UpdateCanisterMetadataPayload {
  canisterId: Principal;
  name?: string;
  description?: string;
}

export const useUpdateCanisterMetadata = () => {
  const { backend } = useHistoryBackend();
  const queryClient = useQueryClient();
  const { enqueueSnackbar } = useSnackbar();
  return useMutation(
    ({ canisterId, name, description }: UpdateCanisterMetadataPayload) =>
      backend.update_metadata(
        canisterId,
        typeof name !== "undefined" ? [name] : [],
        typeof description !== "undefined" ? [description] : []
      ),
    {
      onSuccess: (_, { canisterId }) => {
        queryClient.invalidateQueries([
          "canister-metadata",
          canisterId.toString(),
        ]);
        enqueueSnackbar("The canister metadata has been successfully updated", {
          variant: "success",
        });
      },
      onError: () => {
        enqueueSnackbar("Failed to update the canister metadata", {
          variant: "error",
        });
      },
    }
  );
};

export const useCanisterStatus = (canisterId: Principal, enabled: boolean) => {
  const { management } = useManagementCanister();
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    ["canister-status", canisterId.toString()],
    () => management.canister_status({ canister_id: canisterId }),
    {
      onError: () => {
        enqueueSnackbar("Failed to fetch the canister status", {
          variant: "error",
        });
      },
      enabled,
    }
  );
};
