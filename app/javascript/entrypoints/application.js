import $ from "jquery";
window.jQuery = $;
window.$ = $;

import Rails from "@rails/ujs";
Rails.start();

// Common imports for all controllers
import "@/core/analytics.js";
import "@/core/autocomplete_loader.js";
import "@/core/common.js";
import "@/core/dtext_formatter_loader.js";
import "@/core/hotkeys.js";
import "@/core/navigation.js";
import "@/core/news_updates.js";
import "@/core/paginator.js";
import "@/core/password.js";
import "@/core/themes.js";
import "@/core/thumbnails.js";
import "@/core/tos_warning.js";

// Exported to window.E621 for debugging and legacy support.
import LStorage from "@/utility/storage.js";
import Settings from "@/utility/settings.js";
import Blacklist from "@/core/blacklists.js";
import Logger from "@/components/debug_logger.js";

function inError (msg) {
  $(window).trigger("danbooru:error", msg);
}

function inNotice (msg) {
  $(window).trigger("danbooru:notice", msg);
}

window.E621 = {
  LStorage,
  Settings,
  Blacklist,
  Logger,
  error: inError,
  notice: inNotice,
};
window.Danbooru = window.E621;

Logger.log("Initialized");
