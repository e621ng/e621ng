import MobileTabs from "@/components/MobileTabs";
import CStorage from "@/utility/storage/Cookie";

type MobileTab = "comments" | "tags";

/** The comments / tags tabs and the "go up" button in the mobile posts#show layout. */
export default class PostMobileLayout {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: PostMobileLayout | null = null;
  public static get instance (): PostMobileLayout {
    if (!PostMobileLayout._instance)
      PostMobileLayout._instance = new PostMobileLayout();
    return PostMobileLayout._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private constructor () {
    if (PostMobileLayout._instance)
      throw new Error("PostMobileLayout is a singleton class. Use PostMobileLayout.instance to access the instance.");

    this.initTabs();
    $(".go-up button").on("click", () => {
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
  }

  private initTabs (): void {
    const root = document.getElementById("mobile-tabs");
    if (!root) return;

    const tabs = MobileTabs.init(root);
    // Registered afterwards: the anchor is a one-off, not a preference to remember.
    this.openCommentAnchor(tabs);
    tabs.onChange((key) => {
      CStorage.Posts.MobileTabState = key as MobileTab;
    });
  }

  /** Comment anchor links will not work on mobile unless the user has the comments tab open. */
  private openCommentAnchor (tabs: MobileTabs): void {
    // Mirrors breakpoints.$desktop in base/_breakpoints.scss
    if (window.matchMedia("(min-width: 50rem)").matches || tabs.active === "comments") return;
    const commentID = window.location.hash.match(/^#?comment-(\d+)/)?.[1];
    if (!commentID) return;
    const comment = $(`article[data-comment-id="${commentID}"]`);
    if (!comment.length) return;

    if (!tabs.switchTo("comments")) return;
    // If the tabs get switched early enough, the browser will scroll to the content on its own.
    window.setTimeout(() => {
      const offset = comment.offset()?.top ?? 0;
      if (offset) window.scrollTo({ top: offset, behavior: "smooth" });
    }, 100);
  }
}
