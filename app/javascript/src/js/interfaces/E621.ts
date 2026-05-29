import Autocomplete from "@/components/autocomplete";
import DTextFormatter from "@/components/DTextFormatter";
import ThumbnailEngine from "@/components/ThumbnailEngine";
import Blacklist from "@/core/blacklists";
import DeferredPostLoader from "@/core/DeferredPostLoader";
import Hotkeys from "@/core/hotkeys";
import PostCache from "@/models/PostCache";
import Logger from "@/utility/Logger";
import ModuleRegistry from "@/utility/ModuleRegistry";
import PerformanceTracker from "@/utility/PerformanceTracker";
import Settings from "@/utility/Settings";
import LStorage from "@/utility/Storage";
import CStorage from "@/utility/StorageC";
import ToastManager from "@/utility/Toast";

export default interface E621Type {
  Registry: ModuleRegistry;
  Performance: PerformanceTracker;
  Logger: typeof Logger;

  CStorage: typeof CStorage;
  LStorage: typeof LStorage;
  Settings: typeof Settings;

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

    CStorage,
    LStorage,
    Settings,

    Hotkeys,
    Toast: ToastManager,

    Autocomplete,
    Blacklist,
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
function deprecated<T extends (...args: any[]) => void>(method: T, warningMessage: string): T {
  return function (this: any, ...args: any[]) {
    console.warn(warningMessage);
    return method(...args);
  } as unknown as T;
}
