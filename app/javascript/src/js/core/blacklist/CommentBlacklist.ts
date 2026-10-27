import Blacklist from "@/core/blacklist";
import CurrentUser from "@/models/CurrentUser";

/**
 * Hides comments from users named in the blacklist through `user:`, `username:`, or `userid:` lines.
 * This is extraordinarily silly; we need a proper user ignoring system.
 */
export default class CommentBlacklist {

  private static isListening = false;

  public static initializeAll () {
    if (!CurrentUser.settings.blacklistUsers) return;

    CommentBlacklist.apply();
    if (CommentBlacklist.isListening) return;
    CommentBlacklist.isListening = true;
    document.addEventListener("e621:blacklist:changed", () => CommentBlacklist.apply());
  }

  /** Re-marks every comment on the page from the current filters. */
  public static apply () {
    $("article.blacklisted-user").removeClass("blacklisted-user");

    for (const filter of Object.values(Blacklist.filters)) {
      // Only the first token is accepted
      // If the user is trying something wackier, that's their fault
      if (!filter.tokens.length) continue;
      const token = filter.tokens[0];

      switch (token.type) {
        case "user":
        case "username":
          CommentBlacklist.hideComments("creator", token.value);
          break;
        case "userid":
          CommentBlacklist.hideComments("creator-id", token.value);
          break;
      }
    }
  }

  /**
   * Marks all comments from a given user.
   * @param attr Data-attribute to match against
   * @param value Value to match against
   */
  private static hideComments (attr: "creator" | "creator-id", value: string | number) {
    const escaped = String(value).replace(/["\\]/g, "\\$&");
    $(`article[data-${attr}="${escaped}"]`).addClass("blacklisted-user");
  }
}
