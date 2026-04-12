import $ from "jquery";
window["jQuery"] = $;
window.$ = $;

import Rails from "@rails/ujs";
Rails.start();

// Common imports for all controllers
import "@/core/analytics";
import "@/core/autocomplete_loader";
import "@/core/common";
import "@/core/dtext_formatter_loader";
import "@/core/forum_topics"; // This is bad, see file for details.
import "@/core/hotkeys";
import "@/core/navigation";
import "@/core/news_updates";
import "@/core/paginator";
import "@/core/password";
import "@/core/themes";
import "@/core/thumbnails";
import "@/core/tos_warning";
import "@/core/user_warning"; // Realistically, should only be on specific pages

// Exported to window.E621 for debugging and legacy support.
import LStorage from "@/utility/storage";
import Settings from "@/utility/settings";
import Blacklist from "@/core/blacklists";
import Flash from "@/components/Flash";
import Logger from "@/components/Logger";

window["E621"] = {
  LStorage,
  Settings,
  Blacklist,
  Logger,
  Flash,
} as E621Type;
window["Danbooru"] = window["E621"];

Logger.log("Initialized");

interface E621Type {
  LStorage: typeof LStorage;
  Settings: typeof Settings;
  Blacklist: typeof Blacklist;
  Logger: typeof Logger;
  Flash: typeof Flash;
}
