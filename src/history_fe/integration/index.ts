import { useMutation, useQuery, useQueryClient } from "react-query";
import { enqueueSnackbar, useSnackbar } from "notistack";
import { Principal } from "@icp-sdk/core/principal";
import {
  ActorSubclass,
  Actor,
  HttpAgent,
  Cbor as cbor,
  HashTree,
  Certificate,
  LookupPathStatus,
  reconstruct,
} from "@icp-sdk/core/agent";
import { safeGetCanisterEnv } from "@icp-sdk/core/agent/canister-env";
import { IDL } from "@icp-sdk/core/candid";
import { decodeFirst, TagDecoder } from "cborg";

import { createActor, History_be, Result_1, TrackError } from "@bindings/history_be";
import { BLACKHOLE_CANISTERS } from "@fe/constants/blackholeCanisters";
import {
  createActor as metadataDirectoryCreateActor,
  Metadata_directory,
  WasmMetadata,
} from "@bindings/metadata_directory";

import { _SERVICE as MANAGEMENT_SERVICE } from "./management_idl/did";
import { idlFactory as managementIdlFactory } from "./management_idl/idl";
import { useIdentity } from "./identity";
import {
  arrayBufferToHex,
  parseUint8ArrayToText,
  resolveDataOrNullError,
  resolveResult,
  resolveTrackManyResult,
} from "./utils";

export const BACKEND_CANISTER_ID =
  safeGetCanisterEnv()?.["PUBLIC_CANISTER_ID:history_be"] ?? "";
export const METADATA_DIRECTORY_BACKEND_CANISTER_ID =
  safeGetCanisterEnv()?.["PUBLIC_CANISTER_ID:metadata_directory"] ?? "";
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

const getBackendFromCache = memoize<History_be>();
export const useHistoryBackend = () => {
  const { httpAgent, uniqueKey } = useHttpAgent();
  const backend = getBackendFromCache(
    () => createActor(BACKEND_CANISTER_ID, { agent: httpAgent }),
    [uniqueKey]
  );
  return { backend };
};

const getMetadataDirectoryFromCache = memoize<Metadata_directory>();
export const useMetadataDirectory = () => {
  const { httpAgent, uniqueKey } = useHttpAgent();
  const metadataDirectory = getMetadataDirectoryFromCache(
    () =>
      metadataDirectoryCreateActor(METADATA_DIRECTORY_BACKEND_CANISTER_ID, {
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
        rootKey: safeGetCanisterEnv()?.IC_ROOT_KEY,
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
  const queryClient = useQueryClient();
  const { backend } = useHistoryBackend();
  const { enqueueSnackbar } = useSnackbar();
  return useMutation(
    (canisterId: Principal) => backend.track(canisterId).then(resolveResult),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(["total-canisters"]);
        queryClient.invalidateQueries(["tracking-stats"]);

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

export const useTrackMany = () => {
  const queryClient = useQueryClient();
  const { backend } = useHistoryBackend();
  const { enqueueSnackbar } = useSnackbar();
  return useMutation(
    (canisterIds: Array<Principal>) =>
      backend
        .trackMany(null, canisterIds)
        .then((res: Result_1[]) => resolveTrackManyResult<null, TrackError>(res, canisterIds)),
    {
      onSuccess: (data: Array<
        { canisterId: string } & (
        | { ok: true; data: null }
        | { ok: false; data: { message: string } }
        )
      >) => {
        queryClient.invalidateQueries(["total-canisters"]);
        queryClient.invalidateQueries(["tracking-stats"]);

        const total = data.length;
        const successful = data.reduce((acc, item) => acc + Number(item.ok), 0);

        if (total === successful) {
          enqueueSnackbar(`Successfully tracked ${successful} canisters`, {
            variant: "success",
          });
        } else if (successful !== 0) {
          enqueueSnackbar(
            `Tracked ${successful} canisters, ${total - successful} failed`,
            {
              variant: "warning",
            }
          );
        } else {
          enqueueSnackbar(`Failed to track all ${total} canisters`, {
            variant: "error",
          });
        }
      },
      onError: () => {
        enqueueSnackbar("Failed to track the canisters", {
          variant: "error",
        });
      },
    }
  );
};

export const useGetTrackedCanistersTotal = () => {
  const { backend } = useHistoryBackend();
  return useQuery(
    ["total-canisters"],
    () => backend.tracked_canisters_total(),
    {
      onError: () => {
        enqueueSnackbar("Failed to fetch the tracked canisters total", {
          variant: "error",
        });
      },
    }
  );
};

export const useGetTrackingStats = () => {
  const { backend } = useHistoryBackend();
  return useQuery(["tracking-stats"], () => backend.get_tracking_stats(), {
    onError: () => {
      enqueueSnackbar("Failed to fetch tracking stats", {
        variant: "error",
      });
    },
  });
};

export const useGetLastRoundDetails = () => {
  const { backend } = useHistoryBackend();
  const { enqueueSnackbar } = useSnackbar();
  return useQuery(
    ["last-round-details"],
    () => backend.last_round_details(null),
    {
      onError: () => {
        enqueueSnackbar("Failed to fetch the last round details", {
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
    () => backend.canister_changes(canisterId).then(resolveDataOrNullError),
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

const assetsIdlFactory: IDL.InterfaceFactory = ({ IDL }) =>
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
  });

export const useAssetsRootHash = (canisterId: Principal, enabled: boolean) => {
  const { httpAgent } = useHttpAgent();
  const { enqueueSnackbar } = useSnackbar();

  const { data } = useReadState(canisterId, enabled);

  return useQuery(
    ["assets-root-hash", canisterId.toString()],
    async () => {
      const assetCanister = Actor.createActor<AssetCanisterActor>(
        assetsIdlFactory,
        { canisterId, agent: httpAgent }
      );

      const result = await assetCanister.certified_tree({});

      const hashTree: HashTree = cbor.decode(new Uint8Array(result.tree));

      const reconstructed = await reconstruct(hashTree);

      const rootHash = arrayBufferToHex(reconstructed);

      return { rootHash };
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

export const useAssetsFrozen = (canisterId: Principal, enabled: boolean) => {
  const { httpAgent } = useHttpAgent();
  const { enqueueSnackbar } = useSnackbar();

  const { data } = useReadState(canisterId, enabled);

  return useQuery(
    ["assets-frozen", canisterId.toString()],
    async () => {
      const assetCanister = Actor.createActor<AssetCanisterActor>(
        assetsIdlFactory,
        { canisterId, agent: httpAgent }
      );

      const authorized = await assetCanister.list_authorized();

      const isUncontrollable = data!.controllers.every((c) =>
        BLACKHOLE_CANISTERS.includes(c)
      );

      const isFrozen = authorized.length === 0 && isUncontrollable;

      return { isFrozen };
    },
    {
      enabled: enabled && !!data,
      onError: () => {
        enqueueSnackbar("Failed to check if the assets are frozen", {
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
      const moduleHashPath: Uint8Array[] = [
        new TextEncoder().encode("canister"),
        canisterId.toUint8Array(),
        new TextEncoder().encode("module_hash"),
      ];

      const controllersPath: Uint8Array[] = [
        new TextEncoder().encode("canister"),
        canisterId.toUint8Array(),
        new TextEncoder().encode("controllers"),
      ];

      const res = await httpAgent.readState(canisterId.toString(), {
        paths: [moduleHashPath, controllersPath],
      });

      const cert = await Certificate.create({
        certificate: res.certificate,
        rootKey: safeGetCanisterEnv()?.IC_ROOT_KEY ?? new Uint8Array(),
        principal: { canisterId },
      });

      const data: { moduleHash: string; controllers: Array<string> } = {
        moduleHash: "",
        controllers: [],
      };

      const moduleHash = cert.lookup_path(moduleHashPath);
      if (moduleHash.status === LookupPathStatus.Found) {
        const hex = arrayBufferToHex(moduleHash.value);
        data.moduleHash = hex;
      } else if (moduleHash.status === LookupPathStatus.Absent) {
        data.moduleHash = "Absent";
      } else {
        throw new Error(`module_hash LookupStatus: ${moduleHash.status}`);
      }

      const controllers = cert.lookup_path(controllersPath);
      if (controllers.status === LookupPathStatus.Found) {
        const tags: TagDecoder[] = [];
        tags[55799] = (val: any) => val;

        const [decoded]: [Uint8Array[], Uint8Array] = decodeFirst(
          controllers.value,
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
    () => backend.metadata(canisterId).then(resolveDataOrNullError),
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
          typeof name !== "undefined" ? name : null,
          typeof description !== "undefined" ? description : null
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
        content: parseUint8ArrayToText(record.content),
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
    () => metadataDirectory.wasm_metadata(null),
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
  moduleHash: Uint8Array;
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
          description,
          build_instructions: buildInstructions,
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
  moduleHash: Uint8Array;
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
          description,
          build_instructions: buildInstructions,
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
  moduleHash: Uint8Array;
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
    () : Promise<Array<[Principal, WasmMetadata]>> => metadataDirectory.find_wasm_metadata(moduleHash, principals),
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
  moduleHashes: Array<Uint8Array>;
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
    () : Promise<Array<[Principal, Uint8Array, bigint]>>  => metadataDirectory.available_metadata(principals, moduleHashes),
    {
      onError: () => {
        enqueueSnackbar("Failed to get the available metadata", {
          variant: "error",
        });
      },
    }
  );
};
