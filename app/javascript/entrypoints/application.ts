import $ from "jquery";
window["jQuery"] = $;
window["$"] = $;

import Rails from "@rails/ujs";
Rails.start();

// Common imports for all controllers
import Autocomplete from "@/components/autocomplete";
import Flash from "@/components/Flash";
import Logger from "@/components/Logger";
import ModuleRegistry from "@/components/ModuleRegistry";
import "@/core/analytics";
import Blacklist from "@/core/blacklists";
import "@/core/common";
import "@/core/dtext_formatter_loader";
import Hotkeys from "@/core/hotkeys";
import "@/core/navigation";
import "@/core/news_updates";
import "@/core/paginator";
import "@/core/password";
import "@/core/themes";
import Thumbnails from "@/core/thumbnails";
import "@/core/tos_warning";
import "@/core/user_warning"; // Realistically, should only be on specific pages
import E621Type from "@/interfaces/E621";
import Settings from "@/utility/settings";
import LStorage from "@/utility/storage";

window["E621"] = {
  Registry: new ModuleRegistry(),
  LStorage,
  Settings,
  Blacklist,
  Thumbnails,
  Autocomplete,
  Hotkeys,
  Logger,
  Flash,

  // compatibility aliases
  error: Flash.error,
  notice: Flash.notice,
} as E621Type;
window["Danbooru"] = window["E621"];

Logger.log("Initialized");
