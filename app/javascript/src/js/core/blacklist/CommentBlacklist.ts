import CurrentUser from "@/models/CurrentUser";
import Blacklist from "@/core/blacklist";

export default class CommentBlacklist {
  public static initializeAll () {
    if (!CurrentUser.settings.blacklistUsers) return;

    // This is extraordinarily silly
    // We need a proper user ignoring system
    for (const filter of Object.values(Blacklist.filters)) {

      // Only the first token is accepted
      // If the user is trying something wackier, that's their fault
      if (!filter.tokens.length) continue;
      const token = filter.tokens[0];

      switch (token.type) {
        case "user": {
          if (token.value.startsWith("!")) {
            CommentBlacklist.hideComment("creator-id", token.value.slice(1));
            continue;
          }
          // falls through
        }
        case "username": {
          CommentBlacklist.hideComment("creator", token.value);
          continue;
        }
        case "userid": {
          CommentBlacklist.hideComment("creator-id", token.value);
          continue;
        }
      }
    }
  }

  /**
   * Hides all comments from a given user.
   * @param attr Data-attribute to match against
   * @param value Value to match against
   */
  private static hideComment (attr: "creator" | "creator-id", value: string) {
    value = CSS.escape(value);
    $(`article[data-${attr}="${value}"]`).hide();
  }
}
