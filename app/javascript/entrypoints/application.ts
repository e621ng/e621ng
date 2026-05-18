import $ from "jquery";
window["jQuery"] = $;
window["$"] = $;

import Rails from "@rails/ujs";
Rails.start();

// Common imports for all controllers
import "@/core/analytics";
import "@/core/AuthOverlay";
import "@/core/common";
import "@/core/dtext_formatter_loader";
import "@/core/Navigation";
import "@/core/news_updates";
import "@/core/paginator";
import "@/core/themes";
import "@/core/tos_warning";
import "@/core/user_warning"; // Realistically, should only be on specific pages
import { makeE621Instance } from "@/interfaces/E621";
import Logger from "@/utility/Logger";
import ToastManager from "@/utility/Toast";

Logger.log("Loading");

// NOTE: When making changes to this object, ensure that the interface
// in app/javascript/src/js/interfaces/E621.ts is updated accordingly.

window["Danbooru"] = window["E621"] = makeE621Instance();

ToastManager.bootstrap();

