import { Principal } from "@icp-sdk/core/principal";

export const arrayBufferToHex = (buffer: Uint8Array | ArrayBuffer): string => {
  const byteArray = new Uint8Array(buffer);
  const hexParts: string[] = [];

  byteArray.forEach((byte) => {
    const hex = byte.toString(16).padStart(2, "0");
    hexParts.push(hex);
  });

  return hexParts.join("");
};

export const parseUint8ArrayToText = (data: Uint8Array | ArrayBuffer): string => {
  const decoder = new TextDecoder("utf-8");
  return decoder.decode(data);
};

const getVariantErrorMessage = (variant: {
  __kind__: string;
  [x: string]: unknown;
}): string => {
  const payload = (variant as Record<string, { message: string }>)[
    variant.__kind__
  ];
  return payload.message;
};

export const resolveResult = <R, E extends { __kind__: string }>(
  result: { __kind__: "ok"; ok: R } | { __kind__: "err"; err: E }
): R => {
  if (result.__kind__ === "err") {
    throw new Error(getVariantErrorMessage(result.err));
  }
  return result.ok;
};

// Resolves trackMany result item
export const resolveTrackManyResult = <R, E extends { __kind__: string }>(
  resultItems: Array<
    { __kind__: "ok"; ok: R } | { __kind__: "err"; err: E }
  >,
  canisterIds: Array<Principal>
): Array<
  { canisterId: string } & (
    | { ok: true; data: R }
    | { ok: false; data: { message: string } }
  )
> => {
  return resultItems.map((res, i) => {
    if (res.__kind__ === "err") {
      const payload = (
        res.err as unknown as Record<string, { message: string }>
      )[res.err.__kind__];
      return {
        canisterId: canisterIds[i].toText(),
        ok: false,
        data: payload,
      };
    }
    return { canisterId: canisterIds[i].toText(), ok: true, data: res.ok };
  });
};

export const resolveDataOrNullError = <T>(data: T | null): T => {
  if (data !== null) {
    return data;
  }
  throw new Error();
};
