export const getSHA256Hash = (data: Uint8Array | number[]): string => {
  return Array.from(data)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
};

export const fromSHA256Hash = (hash: string): Uint8Array => {
  if (hash.length % 2 !== 0) {
    throw new Error("Invalid hash string length");
  }

  const byteArray = new Uint8Array(hash.length / 2);

  for (let i = 0; i < hash.length; i += 2) {
    byteArray[i / 2] = parseInt(hash.substr(i, 2), 16);
  }

  return byteArray;
};

export const isValidSHA256Hash = (hash: string): boolean => {
  if (hash.length !== 64) return false;
  const hexRegex = /^[a-fA-F0-9]{64}$/;
  return hexRegex.test(hash);
};
