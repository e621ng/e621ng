import Autocomplete from "@/components/autocomplete";
import DTextFormatter from "@/components/DTextFormatter";
import ThumbnailEngine from "@/components/ThumbnailEngine";
import Timestamp from "@/components/Timestamp";
import Blacklist from "@/core/blacklists";
import DeferredPostLoader from "@/core/DeferredPostLoader";
import Hotkeys from "@/core/hotkeys";
import PostCache from "@/models/PostCache";
import Logger from "@/utility/Logger";
import ModuleRegistry from "@/utility/ModuleRegistry";
import PerformanceTracker from "@/utility/PerformanceTracker";
import Settings from "@/utility/Settings";
import LStorage from "@/utility/storage";
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
  Timestamp: typeof Timestamp,

  // compatibility aliases
  error: (message: string) => void,
  notice: (message: string, permanent?: boolean) => void,
  Flash: {
    error: (message: string) => void,
    notice: (message: string, permanent?: boolean) => void,
  },
}

export function makeE621Instance (): E621Type {
  return {
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
    Timestamp,

    // compatibility aliases
    error: ToastManager.alert,
    notice: ToastManager.notice,
    Flash: {
      notice: ToastManager.notice,
      error: ToastManager.alert,
    },
  };
}
