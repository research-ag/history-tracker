export const arrayBufferToHex = (buffer: ArrayBuffer): string => {
  const byteArray = new Uint8Array(buffer);
  const hexParts: string[] = [];

  byteArray.forEach((byte) => {
    const hex = byte.toString(16).padStart(2, "0");
    hexParts.push(hex);
  });

  return hexParts.join("");
};

export const parseUint8ArrayToText = (data: ArrayBuffer): string => {
  const decoder = new TextDecoder("utf-8");
  return decoder.decode(data);
};

export const resolveResult = <
  R,
  E extends { [x: string]: { message: string } }
>(
  result: { ok: R } | { err: E }
) => {
  if ("err" in result) {
    const key = Object.keys(result.err)[0];
    const msg = result.err[key].message;
    throw new Error(msg);
  }
  return result.ok;
};

export const resolveDataOrNullError = <T>(data: [] | [T]): T => {
  if (data[0]) {
    return data[0];
  }
  throw new Error();
};
