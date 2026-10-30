import CurrentUser from "@/models/CurrentUser";

/** The blacklist toggle buttons next to each tag in the posts sidebar. */
export default class BlacklistQuickToggle {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: BlacklistQuickToggle | null = null;
  public static get instance (): BlacklistQuickToggle {
    if (!BlacklistQuickToggle._instance)
      BlacklistQuickToggle._instance = new BlacklistQuickToggle();
    return BlacklistQuickToggle._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private tagListCache: Record<string, JQuery<HTMLElement>> = {};

  private constructor () {
    if (BlacklistQuickToggle._instance)
      throw new Error("BlacklistQuickToggle is a singleton class. Use BlacklistQuickToggle.instance to access the instance.");

    for (const entry of $("li.tag-list-item"))
      this.tagListCache[decodeURIComponent(entry.dataset.name)] = $(entry);
    this.markBlacklisted();

    $(".tag-list-actions button").on("click", (event) => {
      const target = $(event.currentTarget);
      const tag = target.data("tag");
      if (!tag) return;

      if (CurrentUser.blacklist.includes(tag)) {
        if (!confirm(`Are you sure you want to remove "${tag}" from your blacklist?`)) return;
        CurrentUser.blacklist = CurrentUser.blacklist.filter(n => n !== tag);
        target.parents(".tag-list-item").removeClass("blacklisted");
      } else {
        if (!confirm(`Are you sure you want to add "${tag}" to your blacklist?`)) return;
        CurrentUser.blacklist.push(tag);
        target.parents(".tag-list-item").addClass("blacklisted");
      }
    });

    // Regenerate sidebar toggles
    document.addEventListener("e621:blacklistUpdated", () => {
      $("li.tag-list-item.blacklisted").removeClass("blacklisted");
      this.markBlacklisted();
    });
  }

  private markBlacklisted (): void {
    for (const one of CurrentUser.blacklist) {
      if (one.includes(" ") || !this.tagListCache[one]) continue;
      this.tagListCache[one].addClass("blacklisted");
    }
  }
}
