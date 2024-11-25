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
