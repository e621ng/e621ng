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
}
