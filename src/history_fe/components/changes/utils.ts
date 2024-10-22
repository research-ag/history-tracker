import { ExtendedChange } from "@declarations/history_be/history_be.did";

export const addGaps = (
  changes: Array<ExtendedChange>
): Array<ExtendedChange | number> => {
  if (changes.length < 2) {
    return [...changes];
  }

  let changesWithGaps: Array<ExtendedChange | number> = [];

  changesWithGaps.push(changes[0]);

  for (let i = 1; i < changes.length; i++) {
    const prev = changes[i - 1];
    const cur = changes[i];

    let delta = Math.abs(Number(cur.change_index) - Number(prev.change_index));

    if (delta !== 1) {
      changesWithGaps.push(delta - 1);
    }

    changesWithGaps.push(cur);
  }

  return changesWithGaps;
};

export const creationExists = (
  changes: Array<ExtendedChange> // sorted by ascending indexes
): boolean => !!changes[0] && Number(changes[0].canister_version) === 0;

export interface NumberOfResetsResult {
  type: "exact" | "unknown";
  resets: number;
}

/**
 * Returns info about the number of resets.
 *
 * 1. creation change exists
 *
 * - max(installs - 1, 0)
 *
 * 2. no creation change:
 *
 * - no install changes: unknown (>= 0)
 * - there is upgrade before the first install change: unknown (>= installs)
 * - default case: unknown (>= installs - 1)
 */
export const getNumberOfResets = (
  changes: Array<ExtendedChange> // sorted by ascending indexes
): NumberOfResetsResult => {
  const installs = changes.reduce<number>((acc, change) => {
    if ("code_deployment" in change.details) {
      const { mode } = change.details.code_deployment;
      if ("reinstall" in mode) return acc + 1;
      if ("install" in mode) return acc + 1;
    }
    return acc;
  }, 0);

  if (creationExists(changes)) {
    return {
      type: "exact",
      resets: Math.max(installs - 1, 0),
    };
  }

  if (installs === 0) {
    return {
      type: "unknown",
      resets: 0,
    };
  }

  // Represents if there is a non-install change
  // before the first install change
  let flag = false;

  for (let change of changes) {
    if ("code_deployment" in change.details) {
      const { mode } = change.details.code_deployment;
      if ("reinstall" in mode) break;
      if ("install" in mode) break;
      flag = true;
      break;
    }
  }

  if (flag) {
    return {
      type: "unknown",
      resets: installs,
    };
  }

  return {
    type: "unknown",
    resets: installs - 1,
  };
};

export const gapsExist = (
  changes: Array<ExtendedChange> // sorted by ascending indexes
) => {
  if (changes.length < 2) return false;
  for (let i = 1; i < changes.length; i++) {
    const prev = changes[i - 1];
    const cur = changes[i];
    let delta = Number(cur.change_index) - Number(prev.change_index);
    if (delta !== 1) return true;
  }
  return false;
};

export type HistorySummary = "complete" | "incomplete" | "gaps";

/**
 * Returns the summary since the creation change.
 *
 * 1. gaps exist: "gaps"
 * 2. no creation change: "incomplete"
 * 3. creation change exists: "complete"
 */
export const getSummarySinceCreation = (
  changes: Array<ExtendedChange> // sorted by ascending indexes
): HistorySummary => {
  if (gapsExist(changes)) return "gaps";
  if (!creationExists(changes)) return "incomplete";
  return "complete";
};

/**
 * Returns the summary since the last reset.
 *
 * Considered slice: [last_install_change, last_change]
 * or [first_change, last_change] if there is no install change
 *
 * 1. gaps exist: "gaps"
 * 2. no install change: "incomplete"
 * 3. install change exists: "complete"
 */
export const getSummarySinceLastReset = (
  changes_: Array<ExtendedChange> // sorted by ascending indexes
): "complete" | "incomplete" | "gaps" => {
  var changes: Array<ExtendedChange> = [...changes_];

  let baseIndex = changes.findLastIndex((change) => {
    if ("code_deployment" in change.details) {
      const { mode } = change.details.code_deployment;
      return "reinstall" in mode || "install" in mode;
    }
    return false;
  });

  const baseChangeIsTracked = baseIndex !== -1;

  // if the base change (install/reinstall) is tracked
  // then we take the slice [last_install_change, last_change]
  if (baseChangeIsTracked) {
    changes = changes.slice(baseIndex);
  }

  if (gapsExist(changes)) return "gaps";
  if (!baseChangeIsTracked) return "incomplete";
  return "complete";
};
