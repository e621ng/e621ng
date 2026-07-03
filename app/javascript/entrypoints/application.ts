import $ from "jquery";
window["jQuery"] = $;
window["$"] = $;

import Rails from "@rails/ujs";
Rails.start();

// Common imports for all controllers
import "@/core/Analytics";
import "@/core/AuthOverlay";
import "@/core/common";
import "@/core/dtext_formatter_loader";
import "@/core/DTextExtras";
import "@/core/Navigation";
import "@/core/news_updates";
import "@/core/paginator";
import "@/core/themes";
import "@/core/tos_warning";
import "@/core/user_warning"; // Realistically, should only be on specific pages
import { getE621Instance } from "@/interfaces/E621";
import Logger from "@/utility/Logger";
import ToastManager from "@/utility/Toast";

Logger.log("Loading");
getE621Instance();
ToastManager.bootstrap();

