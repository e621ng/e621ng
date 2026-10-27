import NoteManager from "@/pages/posts/show/notes";
import ToolbarFavorites from "@/pages/posts/show/toolbar/Favorites";
import ToolbarVoting from "@/pages/posts/show/toolbar/Voting";
import Offclick, { OffclickEntry } from "@/utility/Offclick";
import Page from "@/utility/Page";
import ToastManager from "@/utility/Toast";

/**
 * Entry point for the toolbar underneath the post image.
 * Owns the voting and favorites modules, and wires the notes toggle, share, and overflow menus.
 */
export default class PostsShowToolbar {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: PostsShowToolbar | null = null;
  public static get instance (): PostsShowToolbar {
    if (!PostsShowToolbar._instance)
      PostsShowToolbar._instance = new PostsShowToolbar();
    return PostsShowToolbar._instance;
  }

  public static get Voting (): ToolbarVoting { return ToolbarVoting.instance; }
  public static get Favorites (): ToolbarFavorites { return ToolbarFavorites.instance; }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private overflowMenu: JQuery<HTMLElement>;
  private overflowToggle: JQuery<HTMLElement>;
  private overflowOffclick: OffclickEntry | null = null;

  private constructor () {
    if (PostsShowToolbar._instance)
      throw new Error("PostsShowToolbar is a singleton class. Use PostsShowToolbar.instance to access the instance.");

    this.overflowMenu = $(".ptbr-etc-menu");
    this.overflowToggle = $(".ptbr-etc-toggle");

    if (!Page.matches("posts", "show")) return;

    void ToolbarVoting.instance;
    void ToolbarFavorites.instance;
    this.initNotesToggle();
    this.initOverflowMenu();
    this.initShareMenu();
  }

  private initNotesToggle (): void {
    const buttons = $(".ptbr-notes-button");
    const sync = () => {
      buttons.attr({
        "enabled": String(NoteManager.enabled),
        "aria-pressed": String(NoteManager.enabled),
      });
    };

    sync();
    buttons.on("click", () => { NoteManager.enabled = !NoteManager.enabled; });
    $("#note-container").on("note:visible:true note:visible:false", sync);
  }

  private initOverflowMenu (): void {
    this.overflowToggle.on("click", () => {
      // Register the offclick handler on first use
      if (this.overflowOffclick === null) {
        this.overflowOffclick = Offclick.register(".ptbr-etc-toggle", ".ptbr-etc-menu", () => this.closeOverflowMenu());

        $(".ptbr-etc-download, .ptbr-etc-pool, .ptbr-etc-set, .ptbr-share-button").on("click", () => {
          this.overflowOffclick.disabled = true;
          this.closeOverflowMenu();
        });
      }

      this.overflowOffclick.disabled = !this.overflowOffclick.disabled;
      this.overflowMenu.toggleClass("hidden", this.overflowOffclick.disabled);
      this.overflowToggle.attr("aria-expanded", String(!this.overflowOffclick.disabled));
    });
  }

  private closeOverflowMenu (): void {
    this.overflowMenu.addClass("hidden");
    this.overflowToggle.attr("aria-expanded", "false");
  }

  private initShareMenu (): void {
    $(".ptbr-share-button").on("click", () => {
      $("#ptbr-share-menu").toggleClass("hidden");
    });

    $(".ptbr-share-link").on("click", function () {
      $(this).trigger("select");
    });

    $(".ptbr-share-copy").on("click", (event) => {
      const value = String($(event.currentTarget).data("value"));
      navigator.clipboard.writeText(value).then(() => {
        ToastManager.notice("Link copied to clipboard.");
      }).catch((error) => {
        console.error(error);
        ToastManager.alert("Failed to copy link to clipboard.");
      });
    });
  }
}

$(() => { void PostsShowToolbar.instance; });
