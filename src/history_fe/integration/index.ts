import { useMutation, useQuery, useQueryClient } from "react-query";
import { useSnackbar } from "notistack";
import { Principal } from "@dfinity/principal";
import {
  ActorSubclass,
  Actor,
  HttpAgent,
  Cbor as cbor,
  HashTree,
  Certificate,
  LookupStatus,
  reconstruct,
} from "@dfinity/agent";
import { decodeFirst, TagDecoder } from "cborg";

import { canisterId, createActor } from "@declarations/history_be";
import { _SERVICE } from "@declarations/history_be/history_be.did";
import { BLACKHOLE_CANISTERS } from "@fe/constants/blackholeCanisters";
import {
  canisterId as metadataDirectoryCanisterId,
  createActor as metadataDirectoryCreateActor,
} from "@declarations/metadata_directory";
import { _SERVICE as MD_SERVICE } from "@declarations/metadata_directory/metadata_directory.did";

import { _SERVICE as MANAGEMENT_SERVICE } from "./management_idl/did";
import { idlFactory as managementIdlFactory } from "./management_idl/idl";
import { useIdentity } from "./identity";
import {
  arrayBufferToHex,
  parseUint8ArrayToText,
  resolveResult,
} from "./utils";

export const BACKEND_CANISTER_ID = canisterId;
export const METADATA_DIRECTORY_BACKEND_CANISTER_ID =
  metadataDirectoryCanisterId;
export const MANAGEMENT_CANISTER_ID = "aaaaa-aa";

const memoize = <R>(): ((fn: () => R, deps: any[]) => R) => {
  const map: Record<string, R> = {};
  return (fn: () => R, deps: any[]): R => {
    const depsKey = JSON.stringify(deps);

    if (!map[depsKey]) {
      map[depsKey] = fn();
    }

    return map[depsKey];
  };
};

const getBackendFromCache = memoize<ActorSubclass<_SERVICE>>();
export const useHistoryBackend = () => {
  const { httpAgent, uniqueKey } = useHttpAgent();
  const backend = getBackendFromCache(
    () => createActor(canisterId, { agent: httpAgent }),
    [uniqueKey]
  );
  return { backend };
};

const getMetadataDirectoryFromCache = memoize<ActorSubclass<MD_SERVICE>>();
export const useMetadataDirectory = () => {
  const { httpAgent, uniqueKey } = useHttpAgent();
  const metadataDirectory = getMetadataDirectoryFromCache(
    () =>
      metadataDirectoryCreateActor(metadataDirectoryCanisterId, {
        agent: httpAgent,
      }),
    [uniqueKey]
  );
  return { metadataDirectory };
};

const getManagementFromCache = memoize<ActorSubclass<MANAGEMENT_SERVICE>>();
export const useManagementCanister = () => {
  const { httpAgent, uniqueKey } = useHttpAgent();
  const management = getManagementFromCache(
    () =>
      Actor.createActor(managementIdlFactory, {
        canisterId: MANAGEMENT_CANISTER_ID,
        agent: httpAgent,
      }),
    [uniqueKey]
  );
  return { management };
};

const getHttpAgentFromCache = memoize<HttpAgent>();
export const useHttpAgent = () => {
  const { identity } = useIdentity();
  const uniqueKey = identity.getPrincipal().toText();
  const httpAgent = getHttpAgentFromCache(
    () =>
      HttpAgent.createSync({
        identity,
        verifyQuerySignatures: false,
      }),
    [uniqueKey]
  );
  return { httpAgent, uniqueKey };
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
  return useMutation(
    (canisterId: Principal) => backend.track(canisterId).then(resolveResult),
    {
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
    }
  );
};

export const useGetCanisterChanges = (canisterId: Principal) => {
  const { backend } = useHistoryBackend();
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    ["canister-changes", canisterId.toString()],
    () => backend.canister_changes(canisterId).then(resolveResult),
    {
      onError: () => {
        enqueueSnackbar("Failed to fetch the canister changes", {
          variant: "error",
        });
      },
    }
  );
};

interface CertifiedTreeResult {
  certificate: Uint8Array;
  tree: Uint8Array;
}

interface AssetCanisterInterface {
  certified_tree: (arg: Record<string, never>) => Promise<CertifiedTreeResult>;
  list_authorized: () => Promise<Array<Principal>>;
}

type AssetCanisterActor = ActorSubclass<AssetCanisterInterface>;

export const useAssetsInfo = (canisterId: Principal, enabled: boolean) => {
  const { httpAgent } = useHttpAgent();
  const { enqueueSnackbar } = useSnackbar();

  const { data } = useReadState(canisterId, enabled);

  return useQuery(
    ["assets-root-hash", canisterId.toString()],
    async () => {
      const assetCanister = Actor.createActor<AssetCanisterActor>(
        ({ IDL }) =>
          IDL.Service({
            certified_tree: IDL.Func(
              [IDL.Record({})],
              [
                IDL.Record({
                  certificate: IDL.Vec(IDL.Nat8),
                  tree: IDL.Vec(IDL.Nat8),
                }),
              ],
              ["query"]
            ),
            list_authorized: IDL.Func([], [IDL.Vec(IDL.Principal)]),
          }),
        { canisterId, agent: httpAgent }
      );

      const result = await assetCanister.certified_tree({});

      const hashTree: HashTree = cbor.decode(new Uint8Array(result.tree));

      const reconstructed = await reconstruct(hashTree);

      const rootHash = arrayBufferToHex(reconstructed);

      const authorized = await assetCanister.list_authorized();

      const isUncontrollable = data!.controllers.every((c) =>
        BLACKHOLE_CANISTERS.includes(c)
      );

      const isFrozen = authorized.length === 0 && isUncontrollable;

      return { rootHash, isFrozen };
    },
    {
      enabled: enabled && !!data,
      onError: () => {
        enqueueSnackbar("Failed to fetch the assets root hash", {
          variant: "error",
        });
      },
    }
  );
};

export const useReadState = (canisterId: Principal, enabled: boolean) => {
  const { httpAgent } = useHttpAgent();
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

      const res = await httpAgent.readState(canisterId.toString(), {
        paths: [moduleHashPath, controllersPath],
      });

      const cert = await Certificate.create({
        certificate: res.certificate,
        rootKey: await httpAgent.fetchRootKey(),
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
      enabled,
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
  const { data, isFetching } = useReadState(canisterId, enabled);

  const { identity } = useIdentity();

  const userPrincipal = identity.getPrincipal().toText();

  return {
    callerIsController: (data?.controllers ?? []).includes(userPrincipal),
    callerIsControllerLoading: isFetching,
  };
};

export const useGetCanisterMetadata = (canisterId: Principal) => {
  const { backend } = useHistoryBackend();
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    ["canister-metadata", canisterId.toString()],
    () => backend.metadata(canisterId).then(resolveResult),
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
      backend
        .update_metadata(
          canisterId,
          typeof name !== "undefined" ? [name] : [],
          typeof description !== "undefined" ? [description] : []
        )
        .then(resolveResult),
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
    () =>
      management.canister_status.withOptions({
        effectiveCanisterId: canisterId,
      })({ canister_id: canisterId }),
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
  const { management } = useManagementCanister();
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    ["canister-logs", canisterId.toString()],
    async (): Promise<MappedCanisterLogRecord[]> => {
      const data = await management.fetch_canister_logs.withOptions({
        effectiveCanisterId: canisterId,
      })({
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

// --------------------------
// === Metadata directory ===
// --------------------------

export const useGetWasmMetadata = () => {
  const { metadataDirectory } = useMetadataDirectory();
  const { identity } = useIdentity();
  const userPrincipal = identity.getPrincipal().toText();
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    ["wasm-metadata", userPrincipal],
    () => metadataDirectory.wasm_metadata([]),
    {
      onError: () => {
        enqueueSnackbar("Failed to fetch the wasm metadata", {
          variant: "error",
        });
      },
    }
  );
};

interface AddWasmMetadataPayload {
  moduleHash: Uint8Array | number[];
  description?: string;
  buildInstructions?: string;
}

export const useAddWasmMetadata = () => {
  const { metadataDirectory } = useMetadataDirectory();
  const { identity } = useIdentity();
  const userPrincipal = identity.getPrincipal().toText();
  const queryClient = useQueryClient();
  const { enqueueSnackbar } = useSnackbar();
  return useMutation(
    ({ moduleHash, description, buildInstructions }: AddWasmMetadataPayload) =>
      metadataDirectory
        .add_wasm_metadata({
          module_hash: moduleHash,
          description: typeof description !== "undefined" ? [description] : [],
          build_instructions:
            typeof buildInstructions !== "undefined" ? [buildInstructions] : [],
        })
        .then(resolveResult),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(["wasm-metadata", userPrincipal]);
        enqueueSnackbar("The wasm module has been successfully added", {
          variant: "success",
        });
      },
      onError: () => {
        enqueueSnackbar("Failed to add the wasm module", {
          variant: "error",
        });
      },
    }
  );
};

interface UpdateWasmMetadataPayload {
  moduleHash: Uint8Array | number[];
  description?: string;
  buildInstructions?: string;
}

export const useUpdateWasmMetadata = () => {
  const { metadataDirectory } = useMetadataDirectory();
  const { identity } = useIdentity();
  const userPrincipal = identity.getPrincipal().toText();
  const queryClient = useQueryClient();
  const { enqueueSnackbar } = useSnackbar();
  return useMutation(
    ({
      moduleHash,
      description,
      buildInstructions,
    }: UpdateWasmMetadataPayload) =>
      metadataDirectory
        .update_wasm_metadata({
          module_hash: moduleHash,
          description: typeof description !== "undefined" ? [description] : [],
          build_instructions:
            typeof buildInstructions !== "undefined" ? [buildInstructions] : [],
        })
        .then(resolveResult),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(["wasm-metadata", userPrincipal]);
        enqueueSnackbar("The wasm module has been successfully updated", {
          variant: "success",
        });
      },
      onError: () => {
        enqueueSnackbar("Failed to update the wasm module", {
          variant: "error",
        });
      },
    }
  );
};

interface FindWasmMetadataPayload {
  principals: Array<Principal>;
  moduleHash: Uint8Array | number[];
}

export const useFindWasmMetadata = (
  { principals, moduleHash }: FindWasmMetadataPayload,
  enabled?: boolean
) => {
  const { metadataDirectory } = useMetadataDirectory();
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    [
      "found-wasm-metadata",
      moduleHash?.join(","),
      principals.map((p) => p.toText()).join(","),
    ],
    () => metadataDirectory.find_wasm_metadata(moduleHash, principals),
    {
      enabled,
      keepPreviousData: true,
      onError: () => {
        enqueueSnackbar("Failed to find the wasm metadata", {
          variant: "error",
        });
      },
    }
  );
};

interface AvailableMetadataPayload {
  principals: Array<Principal>;
  moduleHashes: Array<Uint8Array | number[]>;
}

export const useAvailableMetadata = ({
  principals,
  moduleHashes,
}: AvailableMetadataPayload) => {
  const { metadataDirectory } = useMetadataDirectory();
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    [
      "available-metadata",
      principals.map((x) => x.toText()).join(","),
      moduleHashes.map((x) => x.join(",")).join(","),
    ],
    () => metadataDirectory.available_metadata(principals, moduleHashes),
    {
      onError: () => {
        enqueueSnackbar("Failed to get the available metadata", {
          variant: "error",
        });
      },
    }
  );
};
