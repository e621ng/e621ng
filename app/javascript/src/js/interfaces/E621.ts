import Autocomplete from "@/components/autocomplete";
import DTextFormatter from "@/components/DTextFormatter";
import ThumbnailEngine from "@/components/ThumbnailEngine";
import Blacklist from "@/core/blacklist";
import DeferredPostLoader from "@/core/DeferredPostLoader";
import Hotkeys from "@/core/hotkeys";
import CurrentUser from "@/models/CurrentUser";
import PostCache from "@/models/PostCache";
import Logger from "@/utility/Logger";
import ModuleRegistry from "@/utility/ModuleRegistry";
import PerformanceTracker from "@/utility/PerformanceTracker";
import Settings from "@/utility/Settings";
import CStorage from "@/utility/storage/Cookie";
import LStorage from "@/utility/storage/Local";
import SStorage from "@/utility/storage/Session";
import ToastManager from "@/utility/Toast";

export default interface E621Type {
  Registry: ModuleRegistry;
  Performance: PerformanceTracker;
  Logger: typeof Logger;

  Storage: Storage;
  Settings: typeof Settings;
  CurrentUser: typeof CurrentUser;

  Hotkeys: typeof Hotkeys;
  Toast: typeof ToastManager;

  Autocomplete: typeof Autocomplete;
  Blacklist: typeof Blacklist;
  DeferredPostLoader: typeof DeferredPostLoader;
  DTextFormatter: typeof DTextFormatter;
  PostCache: typeof PostCache;
  ThumbnailEngine: typeof ThumbnailEngine;

  // compatibility aliases
  notice: typeof ToastManager.notice;
  error: typeof ToastManager.alert;
  Flash: {
    notice: typeof ToastManager.notice;
    error: typeof ToastManager.alert;
  };

  CStorage: typeof CStorage;
  LStorage: typeof LStorage;
  SStorage: typeof SStorage;
}

/**
 * Bootstraps and returns the global e621 instance.
 * Only intended to be used internally; for external usage, access the global `E621` variable directly.
 * @returns The global E621 instance.
 */
export function getE621Instance (): E621Type {
  if (window["E621"])
    return window["E621"] as E621Type;

  const instance = {
    Registry: new ModuleRegistry(),
    Performance: new PerformanceTracker("app"),
    Logger,

    Storage: {
      Cookie: CStorage,
      Local: LStorage,
      Session: SStorage,
    },
    Settings,
    CurrentUser: CurrentUser,

    Hotkeys,
    Toast: ToastManager,

    Autocomplete,
    Blacklist: Blacklist,
    DeferredPostLoader,
    DTextFormatter,
    PostCache,
    ThumbnailEngine,

    // compatibility aliases
    // TODO: Remove after November 2026
    notice: deprecated(ToastManager.notice, "E621.notice is deprecated. Please use E621.Toast.notice instead."),
    error: deprecated(ToastManager.alert, "E621.error is deprecated. Please use E621.Toast.alert instead."),
    Flash: {
      notice: deprecated(ToastManager.notice, "E621.Flash.notice is deprecated. Please use E621.Toast.notice instead."),
      error: deprecated(ToastManager.alert, "E621.Flash.error is deprecated. Please use E621.Toast.alert instead."),
    },

    CStorage: CStorage,
    LStorage: LStorage,
    SStorage: SStorage,
  };

  window["Danbooru"] = window["E621"] = instance;
  return instance;
}

/**
 * Marks a method as deprecated, logging a warning message to the console when it is called.
 * @param method The method to mark as deprecated.
 * @param warningMessage The warning message to log when the method is called.
 * @returns A new method that logs the warning message and then calls the original method.
 */
function deprecated<T extends (...args: any[]) => void> (method: T, warningMessage: string): T {
  return function (this: any, ...args: any[]) {
    console.warn(warningMessage);
    return method(...args);
  } as unknown as T;
}

interface Storage {
  Cookie: typeof CStorage;
  Local: typeof LStorage;
  Session: typeof SStorage;
}
