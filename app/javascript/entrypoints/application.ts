import $ from "jquery";
window["jQuery"] = $;
window["$"] = $;

import Rails from "@rails/ujs";
Rails.start();

// Common imports for all controllers
import Autocomplete from "@/components/autocomplete";
import "@/core/analytics";
import "@/core/AuthOverlay";
import Blacklist from "@/core/blacklists";
import "@/core/common";
import "@/core/dtext_formatter_loader";
import Hotkeys from "@/core/hotkeys";
import "@/core/navigation";
import "@/core/news_updates";
import "@/core/paginator";
import "@/core/themes";
import Thumbnails from "@/core/thumbnails";
import "@/core/tos_warning";
import "@/core/user_warning"; // Realistically, should only be on specific pages
import E621Type from "@/interfaces/E621";
import Appearance from "@/utility/Appearance";
import Flash from "@/utility/Flash";
import Logger from "@/utility/Logger";
import ModuleRegistry from "@/utility/ModuleRegistry";
import PerformanceTracker from "@/utility/PerformanceTracker";
import Settings from "@/utility/Settings";
import LStorage from "@/utility/storage";

Logger.log("Loading");

window["E621"] = {
  Registry: new ModuleRegistry(),
  Performance: new PerformanceTracker("app"),
  LStorage,
  Settings,
  Blacklist,
  Thumbnails,
  Autocomplete,
  Hotkeys,
  Logger,
  Flash,
  Appearance,
  // compatibility aliases
  error: Flash.error,
  notice: Flash.notice,
} as E621Type;
window["Danbooru"] = window["E621"];

