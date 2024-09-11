import { useEffect, useState } from "react";

enum TabId {
  Changes = "changes",
  State = "state",
  Metadata = "metadata",
  Manage = "manage",
}

const toTabId = (tabValue: number): string => {
  if (tabValue === 0) return TabId.Changes;
  if (tabValue === 1) return TabId.State;
  if (tabValue === 2) return TabId.Metadata;
  if (tabValue === 3) return TabId.Manage;
  return "";
};

const fromTabId = (tabId: string): number => {
  if (tabId === TabId.Changes) return 0;
  if (tabId === TabId.State) return 1;
  if (tabId === TabId.Metadata) return 2;
  if (tabId === TabId.Manage) return 3;
  return 0;
};

export const useTabManagement = () => {
  const getTabIdFromQuery = () => {
    const queryParams = new URLSearchParams(window.location.search);
    return queryParams.get("tab") ?? "";
  };

  const [tabValue, setTabValue] = useState(fromTabId(getTabIdFromQuery()));

  useEffect(() => {
    const queryParams = new URLSearchParams(window.location.search);

    queryParams.set("tab", toTabId(tabValue));

    const newUrl = queryParams.toString()
      ? `${window.location.pathname}?${queryParams.toString()}`
      : window.location.pathname;

    window.history.replaceState(null, "", newUrl);
  }, [tabValue]);

  return { tabValue, setTabValue };
};
