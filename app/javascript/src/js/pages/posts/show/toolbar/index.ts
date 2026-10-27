import NoteManager from "@/pages/posts/show/notes";
import ToolbarFavorites from "@/pages/posts/show/toolbar/Favorites";
import ToolbarVoting from "@/pages/posts/show/toolbar/Voting";
import Offclick, { OffclickEntry } from "@/utility/Offclick";
import Page from "@/utility/Page";
import ToastManager from "@/utility/Toast";

/** The toolbar underneath the post image: voting, favorites, notes toggle, share, and overflow menu. */
export default class PostsShowToolbar {

  public static init (): void {
    ToolbarVoting.init();
    ToolbarFavorites.init();
    this.initNotesToggle();
    this.initOverflowMenu();
    this.initShareMenu();
  }

  private static initNotesToggle (): void {
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

  private static initOverflowMenu (): void {
    const menu = $(".ptbr-etc-menu");
    const toggle = $(".ptbr-etc-toggle");
    let offclick: OffclickEntry | null = null;

    const close = () => {
      menu.addClass("hidden");
      toggle.attr("aria-expanded", "false");
    };

    toggle.on("click", () => {
      // Register the offclick handler on first use
      if (offclick === null) {
        offclick = Offclick.register(".ptbr-etc-toggle", ".ptbr-etc-menu", close);

        $(".ptbr-etc-download, .ptbr-etc-pool, .ptbr-etc-set, .ptbr-share-button").on("click", () => {
          offclick.disabled = true;
          close();
        });
      }

      offclick.disabled = !offclick.disabled;
      menu.toggleClass("hidden", offclick.disabled);
      toggle.attr("aria-expanded", String(!offclick.disabled));
    });
  }

  private static initShareMenu (): void {
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

$(() => {
  if (!Page.matches("posts", "show")) return;
  PostsShowToolbar.init();
});
