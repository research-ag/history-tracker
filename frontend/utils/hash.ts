export const getSHA256Hash = (data: Uint8Array | number[]): string => {
  return Array.from(data)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
};
