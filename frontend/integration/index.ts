import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "react-query";
import { useSnackbar } from "notistack";
import { Principal } from "@dfinity/principal";
import {
  ActorSubclass,
  Actor,
  HttpAgent,
  Identity,
  Certificate,
  LookupStatus,
} from "@dfinity/agent";
import { decodeFirst, TagDecoder } from "cborg";

import { canisterId, createActor } from "@declarations/history_be";
import { _SERVICE } from "@declarations/history_be/history_be.did";

import { _SERVICE as MANAGEMENT_SERVICE } from "./management_idl/did";
import { idlFactory as managementIdlFactory } from "./management_idl/idl";
import { useIdentity } from "./identity";
import { arrayBufferToHex, parseUint8ArrayToText } from "./utils";

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

export const useManagementCanister = (effectiveCanisterId: Principal) => {
  const { identity } = useIdentity();
  const [management, setManagement] = useState<
    ActorSubclass<MANAGEMENT_SERVICE>
  >(
    Actor.createActor(managementIdlFactory, {
      canisterId: MANAGEMENT_CANISTER_ID,
      agent: createHttpAgent(identity),
      effectiveCanisterId,
    })
  );

  useEffect(() => {
    setManagement(
      Actor.createActor(managementIdlFactory, {
        canisterId: MANAGEMENT_CANISTER_ID,
        agent: createHttpAgent(identity),
        effectiveCanisterId,
      })
    );
  }, [identity.getPrincipal().toText(), effectiveCanisterId.toText()]);

  return { management };
};

const createHttpAgent = (identity: Identity) => {
  const agent = new HttpAgent({ identity, verifyQuerySignatures: false });
  agent.fetchRootKey().catch((err) => {
    console.warn(
      "Unable to fetch root key. Check to ensure that your local replica is running"
    );
    console.error(err);
  });
  return agent;
};

export const useHttpAgent = () => {
  const { identity } = useIdentity();

  const [httpAgent, setHttpAgent] = useState(createHttpAgent(identity));

  useEffect(() => {
    setHttpAgent(createHttpAgent(identity));
  }, [identity.getPrincipal().toText()]);

  return httpAgent;
};

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

export const useReadState = (canisterId: Principal) => {
  const agent = useHttpAgent();
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    ["canister-module-hash", canisterId.toString()],
    async () => {
      const moduleHashPath: ArrayBuffer[] = [
        new TextEncoder().encode("canister"),
        canisterId.toUint8Array(),
        new TextEncoder().encode("module_hash"),
      ];

      const controllersPath: ArrayBuffer[] = [
        new TextEncoder().encode("canister"),
        canisterId.toUint8Array(),
        new TextEncoder().encode("controllers"),
      ];

      const res = await agent.readState(canisterId.toString(), {
        paths: [moduleHashPath, controllersPath],
      });

      const cert = await Certificate.create({
        certificate: res.certificate,
        rootKey: await agent.fetchRootKey(),
        canisterId,
      });

      const data: { moduleHash: string; controllers: Array<string> } = {
        moduleHash: "",
        controllers: [],
      };

      const moduleHash = cert.lookup(moduleHashPath);
      if (moduleHash.status === LookupStatus.Found) {
        const hex = arrayBufferToHex(moduleHash.value as ArrayBuffer);
        data.moduleHash = hex;
      } else {
        throw new Error(`module_hash LookupStatus: ${moduleHash.status}`);
      }

      const controllers = cert.lookup(controllersPath);
      if (controllers.status === LookupStatus.Found) {
        const tags: TagDecoder[] = [];
        tags[55799] = (val: any) => val;

        const [decoded]: [Uint8Array[], Uint8Array] = decodeFirst(
          new Uint8Array(controllers.value as ArrayBuffer),
          { tags }
        );

        const controllersList = decoded.map((buf) =>
          Principal.fromUint8Array(buf).toText()
        );

        data.controllers = controllersList;
      } else {
        throw new Error(`controllers LookupStatus: ${moduleHash.status}`);
      }

      return data;
    },
    {
      onError: () => {
        enqueueSnackbar("Failed to read the canister state", {
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
  const { management } = useManagementCanister(canisterId);
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

export interface MappedCanisterLogRecord {
  content: string;
  idx: number;
  timestamp_nanos: bigint;
}

export const useFetchCanisterLogs = (
  canisterId: Principal,
  enabled: boolean
) => {
  const { management } = useManagementCanister(canisterId);
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    ["canister-logs", canisterId.toString()],
    async (): Promise<MappedCanisterLogRecord[]> => {
      const data = await management.fetch_canister_logs({
        canister_id: canisterId,
      });

      return data.canister_log_records.map((record) => ({
        idx: Number(record.idx),
        timestamp_nanos: record.timestamp_nanos,
        content: parseUint8ArrayToText(record.content as Uint8Array),
      }));
    },
    {
      onError: () => {
        enqueueSnackbar("Failed to fetch the canister logs", {
          variant: "error",
        });
      },
      enabled,
    }
  );
};
