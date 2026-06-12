import Utility from "@/utility/utility";

export default class Constants {
  static readonly TAG_PREFIXES = ["-", "~"];

  // Passed on from the back-end via meta tags
  static readonly TAG_CATEGORIES: string[] = JSON.parse(Utility.meta("tag-categories") || "[]");
  static readonly METATAGS: string[] = JSON.parse(Utility.meta("metatags") || "[]");
  static readonly ORDER_METATAGS: string[] = JSON.parse(Utility.meta("order-metatags") || "[]");

  static readonly STATIC_METATAGS = {
    order: Constants.ORDER_METATAGS,
    status: ["any", "deleted", "active", "pending", "flagged", "modqueue"],
    rating: ["safe", "questionable", "explicit"],
    locked: ["rating", "note", "status"],
    child: ["any", "none"],
    parent: ["any", "none"],
    filetype: ["jpg", "png", "gif", "swf", "webm", "mp4", "webp"],
    type: ["jpg", "png", "gif", "swf", "webm", "mp4", "webp"], // Consider passing these from the back-end as well
  };

  // Precompiled regexes for performance

  static readonly TAG_PREFIXES_REGEX = new RegExp("^([" + Constants.TAG_PREFIXES.join("") + "]*)(.*)", "i");

  static readonly CATEGORY_PREFIXES_REGEX = Constants.TAG_CATEGORIES.length > 0
    ? new RegExp("^(" + Constants.TAG_CATEGORIES.map(category => category + ":").join("|") + ")(.*)", "i")
    : null;

  static readonly METATAGS_REGEX = Constants.METATAGS.length > 0
    ? new RegExp("^(" + Constants.METATAGS.join("|") + "):(.*)", "i")
    : null;
}
