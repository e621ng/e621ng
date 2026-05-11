import $ from "jquery";
window["jQuery"] = $;
window["$"] = $;

import Rails from "@rails/ujs";
Rails.start();

// Common imports for all controllers
import Autocomplete from "@/components/autocomplete";
import DTextFormatter from "@/components/DTextFormatter";
import ThumbnailEngine from "@/components/ThumbnailEngine";
import "@/core/analytics";
import "@/core/AuthOverlay";
import Blacklist from "@/core/blacklists";
import "@/core/common";
import DeferredPostLoader from "@/core/DeferredPostLoader";
import "@/core/dtext_formatter_loader";
import Hotkeys from "@/core/hotkeys";
import "@/core/navigation";
import "@/core/news_updates";
import "@/core/paginator";
import "@/core/themes";
import "@/core/tos_warning";
import "@/core/user_warning"; // Realistically, should only be on specific pages
import E621Type from "@/interfaces/E621";
import PostCache from "@/models/PostCache";
import Logger from "@/utility/Logger";
import ModuleRegistry from "@/utility/ModuleRegistry";
import PerformanceTracker from "@/utility/PerformanceTracker";
import Settings from "@/utility/Settings";
import LStorage from "@/utility/storage";
import CStorage from "@/utility/StorageC";
import ToastManager from "@/utility/Toast";

Logger.log("Loading");

// NOTE: When making changes to this object, ensure that the interface
// in app/javascript/src/js/interfaces/E621.ts is updated accordingly.

window["E621"] = {
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
  error: ToastManager.alert,
  notice: ToastManager.notice,
  Flash: {
    notice: ToastManager.notice,
    error: ToastManager.alert,
  },
} as E621Type;
window["Danbooru"] = window["E621"];

ToastManager.bootstrap();

