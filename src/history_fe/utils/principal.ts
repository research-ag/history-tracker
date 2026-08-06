import { Principal } from "@icp-sdk/core/principal";

export const validatePrincipals = (value: string) => {
  const principalsText = value.split("\n").filter((str) => !!str);
  return principalsText.every((p) => {
    try {
      Principal.fromText(p);
      return true;
    } catch (_) {
      return false;
    }
  });
};

export const principalsToText = (principals: Array<Principal>) =>
  principals.map((p) => p.toText()).join("\n");

export const textToPrincipals = (sourcesRaw: string) =>
  [...new Set(sourcesRaw.split("\n").filter((str) => !!str))].map((str) =>
    Principal.fromText(str)
  );
