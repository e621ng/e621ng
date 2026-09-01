import Autocomplete from "@/components/autocomplete";
import DTextFormatter from "@/components/DTextFormatter";
import ThumbnailEngine from "@/components/ThumbnailEngine";
import TimestampSwitch from "@/components/TimestampSwitch";
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
  TimestampSwitch: typeof TimestampSwitch;

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

interface Storage {
  Cookie: typeof CStorage;
  Local: typeof LStorage;
  Session: typeof SStorage;
}
