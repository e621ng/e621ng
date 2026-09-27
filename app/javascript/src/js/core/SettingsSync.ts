import CurrentUser from "@/models/CurrentUser";
import HTTP from "@/utility/HTTP";
import LStorage, { StorageKeys } from "@/utility/storage/Local";
import Logger from "@/utility/Logger";
import ToastManager from "@/utility/Toast";
import { StorageMetadata } from "@/utility/storage/utilities/Types";

const log = new Logger("SettingsSync");

type SyncGroup = "Theme" | "Posts" | "Site";

function syncKeyPart (name: string): string {
  return name.replace(/([a-z0-9])([A-Z])/g, "$1_$2").toLowerCase();
}

// Derived from Local.ts's StorageKeys `sync: true` fields, so a syncable setting is
// declared in exactly one place. The backend key is deterministic from its path
// (Theme.Main -> theme_main) and must match UserSetting::ALLOWED_SETTINGS.
const SYNCED_BY_KEY: Record<string, { label: SyncGroup; name: string }> = {};
const KEY_BY_PATH: Record<string, string> = {};

for (const label of ["Theme", "Posts", "Site"] as const) {
  for (const [name, contents] of Object.entries(StorageKeys[label] ?? {})) {
    if (typeof contents !== "object" || contents === null || !(contents as StorageMetadata).sync) continue;

    const key = `${syncKeyPart(label)}_${syncKeyPart(name)}`;
    SYNCED_BY_KEY[key] = { label, name };
    KEY_BY_PATH[`${label}.${name}`] = key;
  }
}

export const SYNCED_SETTING_KEYS = Object.freeze(Object.keys(SYNCED_BY_KEY));

/** This page's account/session assumption no longer holds (see isStaleSessionStatus). */
class StaleSessionError extends Error {}

function expectedUserParams (userId: number): { expected_user_id: number } {
  return { expected_user_id: userId };
}

// 403/409 both mean this page's account/session assumption is wrong; both fail closed the
// same way rather than trusting a rollback or an old value.
function isStaleSessionStatus (status: number): boolean {
  return status === 409 || status === 403;
}

function notifyLocalChange (label: string, name: string, value: unknown, previousValue: unknown): Promise<void> {
  const key = KEY_BY_PATH[`${label}.${name}`];
  if (!key) return Promise.resolve(); // Not a server-syncable setting

  if (CurrentUser.is.anonymous) {
    LStorage.Sync.UserID = -1; // Forces a resync for whoever logs into this browser next
    return Promise.resolve();
  }

  markDirty();
  return pushChange(key, label as SyncGroup, name, value, previousValue);
}

const pendingByKey = new Map<string, Promise<void>>();
const generationByKey = new Map<string, number>();

function nextGeneration (key: string): number {
  const generation = (generationByKey.get(key) ?? 0) + 1;
  generationByKey.set(key, generation);
  return generation;
}

// Only a full GET may advance Sync.Revision or clear Dirty; a PATCH confirms one key,
// not the full account state.
function recordFullSync (userId: number, revision: number, dirtyTokenAtStart: string): void {
  LStorage.Sync.Revision = LStorage.Sync.UserID === userId
    ? Math.max(LStorage.Sync.Revision, revision)
    : revision;
  LStorage.Sync.UserID = userId;

  // DirtyToken having changed since dirtyTokenAtStart means some mutation (this tab or
  // another sharing this localStorage) happened during this GET's flight and was never
  // accounted for by it, so Dirty must survive.
  if (LStorage.Sync.DirtyToken === dirtyTokenAtStart) LStorage.Sync.Dirty = false;
}

function markDirty (): void {
  LStorage.Sync.Dirty = true;
  LStorage.Sync.DirtyToken = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
}

function pushChange (key: string, label: SyncGroup, name: string, value: unknown, previousValue: unknown): Promise<void> {
  const generation = nextGeneration(key);
  const previous = pendingByKey.get(key);
  const current = previous
    ? previous.then(() => performPatch(key, label, name, value, previousValue, generation))
    : performPatch(key, label, name, value, previousValue, generation);
  pendingByKey.set(key, current);
  return current;
}

// Waits until this tab has no settings writes in flight, so a reload (see sync()) can't
// abort one mid-request. Re-snapshots after each wait since a new write can be queued
// while still waiting on the previous batch.
async function waitForPendingWrites (): Promise<void> {
  for (;;) {
    const snapshot = new Map(pendingByKey);
    if (snapshot.size === 0) return;

    await Promise.allSettled(snapshot.values());

    let unchanged = pendingByKey.size === snapshot.size;
    if (unchanged) {
      for (const [key, tail] of pendingByKey) {
        if (snapshot.get(key) === tail) continue;
        unchanged = false;
        break;
      }
    }
    if (unchanged) return;
  }
}

async function performPatch (key: string, label: SyncGroup, name: string, value: unknown, previousValue: unknown, generation: number): Promise<void> {
  try {
    const response = await HTTP.request("/user_settings.json", {
      method: "PATCH",
      params: expectedUserParams(CurrentUser.id),
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ settings: { [key]: value } }),
    });

    if (isStaleSessionStatus(response.status)) throw new StaleSessionError();
    if (!response.ok) throw new Error(`Request failed: ${response.status}`);
  } catch (e) {
    log.error(`Failed to save setting "${key}":`, e);

    if (generationByKey.get(key) !== generation) return; // Superseded by a newer attempt

    if (e instanceof StaleSessionError) {
      markDirty();
      ToastManager.alert("Your session has changed. Please reload the page to continue.");
      return;
    }

    if (LStorage[label][name] === value) { // Only roll back if nothing newer moved the value on
      LStorage[label][name] = previousValue;
      markDirty(); // A full GET may have cleared Dirty since this change first set it
      ToastManager.alert("Failed to save your setting. Please try again.");
    }
  }
}

async function sync (): Promise<void> {
  if (CurrentUser.is.anonymous) return;

  const userId = CurrentUser.id;
  const revision = CurrentUser.settingsRevision;

  if (!LStorage.Sync.Dirty && LStorage.Sync.UserID === userId && LStorage.Sync.Revision === revision) {
    log.log("Settings already in sync");
    return;
  }

  const generationAtStart: Record<string, number> = {};
  for (const key of Object.keys(SYNCED_BY_KEY))
    generationAtStart[key] = generationByKey.get(key) ?? 0;
  const dirtyTokenAtStart = LStorage.Sync.DirtyToken;

  let settings: Record<string, unknown>;
  let fetchedRevision: number;
  try {
    const response = await HTTP.get("/user_settings.json", expectedUserParams(userId));

    if (isStaleSessionStatus(response.status)) {
      markDirty();
      return;
    }
    if (!response.ok) throw new Error(`Request failed: ${response.status}`);

    const data = await response.json() as { settings: Record<string, unknown>; settings_revision: number };
    settings = data.settings || {};
    fetchedRevision = data.settings_revision;
  } catch (e) {
    log.error("Failed to fetch settings:", e);
    return; // Retry on the next normal page load
  }

  // A concurrent GET (this tab or another) can resolve out of order; discard this one if a
  // newer revision for this account already landed. Different accounts' revisions aren't
  // comparable, so this only applies when UserID still matches.
  if (LStorage.Sync.UserID === userId && fetchedRevision < LStorage.Sync.Revision) {
    log.log("Discarding a stale GET response (a newer one already landed)");
    return;
  }

  let needsReload = false;
  for (const [key, { label, name }] of Object.entries(SYNCED_BY_KEY)) {
    if (!(key in settings)) continue; // Server has no opinion on this key

    if ((generationByKey.get(key) ?? 0) !== generationAtStart[key]) continue; // Changed locally during this GET

    const value = settings[key];
    if (LStorage[label][name] === value) continue;

    LStorage[label][name] = value;
    needsReload = true; // Some page JS reads a synced setting before this GET can resolve
  }

  recordFullSync(userId, fetchedRevision, dirtyTokenAtStart);

  if (needsReload) {
    await waitForPendingWrites();
    window.location.reload();
  }
}

const SettingsSync = { sync, notifyLocalChange };
export default SettingsSync;
