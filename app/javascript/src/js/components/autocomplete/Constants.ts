export default class Constants {
  static readonly TAG_PREFIXES = ["-", "~"];

  // Passed on from the back-end via meta tags
  static readonly TAG_CATEGORIES: string[] = Constants.readMetadata("tag-categories");
  static readonly METATAGS: string[] = Constants.readMetadata("metatags");
  static readonly ORDER_METATAGS: string[] = Constants.readMetadata("order-metatags");

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

  static readonly FILETYPE_ALIASES: Record<string, string> = {
    flash: "swf",
  };

  // Precompiled regexes for performance

  static readonly TAG_PREFIXES_REGEX = new RegExp("^([" + Constants.TAG_PREFIXES.join("") + "]*)(.*)", "i");

  static readonly CATEGORY_PREFIXES_REGEX = Constants.TAG_CATEGORIES.length > 0
    ? new RegExp("^(" + Constants.TAG_CATEGORIES.map(category => category + ":").join("|") + ")(.*)", "i")
    : null;

  static readonly METATAGS_REGEX = Constants.METATAGS.length > 0
    ? new RegExp("^(" + Constants.METATAGS.join("|") + "):(.*)", "i")
    : null;

  /**
   * Reads metadata from a meta tag in the document head.
   * @param key The name of the meta tag to read.
   * @returns An array of strings parsed from the meta tag's content, or an empty array if the meta tag is not found or cannot be parsed.
   */
  private static readMetadata (key: string): string[] {
    const element = document.querySelector(`meta[name="${key}"]`);
    if (!element) return [];
    try {
      return JSON.parse(element.getAttribute("content") || "[]");
    } catch {
      console.warn(`Failed to parse metadata for key "${key}".`);
      return [];
    }
  }
}
