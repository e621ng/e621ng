import E621Type from "@/interfaces/E621";

declare const E621: E621Type;

export default class CommentBlacklist {
  public static initializeAll () {
    if (!E621.CurrentUser.settings.blacklistUsers) return;

    // This is extraordinarily silly
    // We need a proper user ignoring system
    for (const filter of Object.values(E621.Blacklist.filters)) {

      // Only the first token is accepted
      // If the user is trying something wackier, that's their fault
      if (!filter.tokens.length) continue;
      const token = filter.tokens[0];

      switch (token.type) {
        case "user": {
          if (token.value.startsWith("!")) {
            $(`article[data-creator-id="${token.value.slice(1)}"]`).hide();
            continue;
          }
          // falls through
        }
        case "username": {
          $(`article[data-creator="${token.value}"]`).hide();
          continue;
        }
        case "userid": {
          $(`article[data-creator-id="${token.value}"]`).hide();
          continue;
        }
      }
    }
  }
}
