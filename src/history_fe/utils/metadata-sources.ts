import { useEffect } from "react";
import { atom, useAtom } from "jotai";
import { Principal } from "@dfinity/principal";

const LS_KEY = "HISTORY_TRACKER_METADATA_SOURCES";

export const validateMetadataSources = (value: string) => {
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

const metadataSourcesAtom = atom<Array<Principal>>([]);

export const useMetadataSources = () => {
  const [metadataSources, _setMetadataSources] =
    useAtom<Array<Principal>>(metadataSourcesAtom);

  useEffect(() => {
    const sourcesRaw = localStorage.getItem(LS_KEY);
    if (typeof sourcesRaw === "string" && validateMetadataSources(sourcesRaw)) {
      const principals = textToPrincipals(sourcesRaw);
      _setMetadataSources(principals);
    }
  }, []);

  const setMetadataSources = (principals: Array<Principal>) => {
    _setMetadataSources(principals);
    const principalsText = principalsToText(principals);
    localStorage.setItem(LS_KEY, principalsText);
  };

  return { metadataSources, setMetadataSources };
};
