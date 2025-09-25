import { useEffect } from "react";
import { atom, useAtom } from "jotai";
import { Principal } from "@dfinity/principal";

import {
  principalsToText,
  textToPrincipals,
  validatePrincipals,
} from "./principal";

const LS_KEY = "HISTORY_TRACKER_METADATA_SOURCES";

const metadataSourcesAtom = atom<Array<Principal>>([]);

export const useMetadataSources = () => {
  const [metadataSources, _setMetadataSources] =
    useAtom<Array<Principal>>(metadataSourcesAtom);

  useEffect(() => {
    const sourcesRaw = localStorage.getItem(LS_KEY);
    if (typeof sourcesRaw === "string" && validatePrincipals(sourcesRaw)) {
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
