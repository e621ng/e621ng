import CStorage from "@/utility/storage/Cookie";

type MobileTab = "comments" | "tags";
const VALID_TABS: MobileTab[] = ["comments", "tags"];

/** The comments / tags tab switcher and the "go up" button in the mobile posts#show layout. */
export default class MobileTabs {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: MobileTabs | null = null;
  public static get instance (): MobileTabs {
    if (!MobileTabs._instance)
      MobileTabs._instance = new MobileTabs();
    return MobileTabs._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private constructor () {
    if (MobileTabs._instance)
      throw new Error("MobileTabs is a singleton class. Use MobileTabs.instance to access the instance.");

    this.initTabs();
    $(".go-up button").on("click", () => {
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
  }

  private initTabs (): void {
    const container = $(".post-display");
    if (!container.length) return;

    container.find(".post-mobile-tab").on("click", (event) => {
      const action = $(event.currentTarget).data("action");
      if (!VALID_TABS.includes(action)) return;
      CStorage.Posts.MobileTabState = action;
      this.switchTo(container, action);
    });

    // Comment anchor links will not work on mobile unless the user has the comments tab open.
    if (window.innerWidth > 800 || CStorage.Posts.MobileTabState === "comments") return;
    const commentID = window.location.hash.match(/^#?comment-(\d+)/)?.[1];
    if (!commentID) return;
    const comment = $(`article[data-comment-id="${commentID}"]`);
    if (!comment.length) return;

    this.switchTo(container, "comments");
    // If the tabs get switched early enough, the browser will scroll to the content on its own.
    window.setTimeout(() => {
      const offset = comment.offset()?.top ?? 0;
      if (offset) window.scrollTo({ top: offset, behavior: "smooth" });
    }, 100);
  }

  private switchTo (container: JQuery<HTMLElement>, tab: MobileTab): void {
    container
      .attr("data-tab-state", tab)
      .find(".post-mobile-tab").each((_, el) => {
        const $el = $(el);
        $el.attr("aria-selected", String($el.data("action") === tab));
      });
  }
}
