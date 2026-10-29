import Hotkeys from "@/core/hotkeys";
import { HotkeyAction } from "@/core/hotkeys/Types";
import CurrentUser from "@/models/CurrentUser";
import BulkActions from "@/pages/posts/BulkActions";
import QuickEdit from "@/pages/posts/QuickEdit";
import PostSet from "@/pages/posts/show/PostSet";
import TagScriptControls from "@/pages/posts/TagScriptControls";
import SStorage from "@/utility/storage/Session";

/** Mirrors the options in posts/partials/index/_mode_menu.html.erb */
export type PostMode = "view" | "edit" | "add-fav" | "remove-fav" | "add-to-set" | "remove-from-set" | "vote-up" | "vote-down" | "rating-s" | "rating-q" | "rating-e" | "tag-script" | "remove-parent" | "lock-rating" | "lock-note" | "approve" | "delete" | "undelete" | "unflag";

const inputValue = (selector: string): string => document.querySelector<HTMLInputElement>(selector)?.value ?? "";

const ACTIONS: Record<Exclude<PostMode, "view">, (post_id: number) => unknown> = {
  "edit": (id) => QuickEdit.instance.open(id),
  "add-fav": (id) => BulkActions.favorite(id),
  "remove-fav": (id) => BulkActions.unfavorite(id),
  "add-to-set": (id) => PostSet.add_post(inputValue("#set-id"), id),
  "remove-from-set": (id) => PostSet.remove_post(inputValue("#set-id"), id),
  "vote-up": (id) => BulkActions.vote(id, 1),
  "vote-down": (id) => BulkActions.vote(id, -1),
  "rating-s": (id) => BulkActions.update(id, { rating: "s" }),
  "rating-q": (id) => BulkActions.update(id, { rating: "q" }),
  "rating-e": (id) => BulkActions.update(id, { rating: "e" }),
  "tag-script": (id) => TagScriptControls.instance.applyTo(id),
  "remove-parent": (id) => BulkActions.update(id, { parent_id: "" }),
  "lock-rating": (id) => BulkActions.update(id, { is_rating_locked: "1" }),
  "lock-note": (id) => BulkActions.update(id, { is_note_locked: "1" }),
  "approve": (id) => BulkActions.approve(id),
  "delete": (id) => BulkActions.delete(id, inputValue("#quick-mode-reason")),
  "undelete": (id) => BulkActions.undelete(id),
  "unflag": (id) => BulkActions.unflag(id, "none"),
};

/**
 * The mode selector on post index and favorites pages: clicking a thumbnail
 * performs the selected action instead of opening the post.
 * The instance is exposed as `E621.PostModeMenu`.
 */
export default class PostModeMenu {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: PostModeMenu | null = null;
  public static get instance (): PostModeMenu {
    if (!PostModeMenu._instance)
      PostModeMenu._instance = new PostModeMenu();
    return PostModeMenu._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private select: HTMLSelectElement | null;

  private constructor () {
    if (PostModeMenu._instance)
      throw new Error("PostModeMenu is a singleton class. Use PostModeMenu.instance to access the instance.");

    this.select = document.querySelector<HTMLSelectElement>("#mode-box-mode");
    if (!this.select) return;

    void QuickEdit.instance;
    void TagScriptControls.instance;

    // Stale or unavailable modes (e.g. after a privilege change) fall back to view
    const options = Array.from(this.select.options, (option) => option.value);
    this.select.value = options.includes(SStorage.Posts.Mode) ? SStorage.Posts.Mode : "view";
    this.select.addEventListener("change", () => this.apply(true));
    this.apply(false);

    document.getElementById("posts")?.addEventListener("click", (event) => this.onClick(event));

    if (CurrentUser.is.privileged) {
      for (let slot = 1; slot <= 9; slot++) {
        Hotkeys.register(`tag-script-${slot}` as HotkeyAction, () => {
          if (this.mode === "tag-script") TagScriptControls.instance.switchSlot(slot);
        });
      }
    }
  }

  public get mode (): PostMode {
    const value = this.select?.value;
    return value && value in ACTIONS ? value as PostMode : "view";
  }

  /** Syncs the page to the selected mode. `userInitiated` announces and focuses the mode's input. */
  private apply (userInitiated: boolean): void {
    QuickEdit.instance.close();

    const mode = this.mode;
    document.getElementById("page")?.setAttribute("data-mode-menu", mode);
    SStorage.Posts.Mode = mode;

    const setSelect = document.querySelector<HTMLSelectElement>("#set-id");
    const isSetMode = mode === "add-to-set" || mode === "remove-from-set";
    toggle(setSelect, isSetMode);
    toggle(document.getElementById("tag-script-ui"), mode === "tag-script");
    toggle(document.getElementById("quick-mode-reason"), mode === "delete");

    if (isSetMode && setSelect) PostSet.populateSelect($(setSelect));
    if (mode === "tag-script") {
      TagScriptControls.instance.activate(userInitiated);
      const field = document.querySelector<HTMLInputElement>("#tag-script-field");
      if (userInitiated && field) {
        field.focus();
        field.select();
      }
    }
  }

  private onClick (event: MouseEvent): void {
    // Modified clicks keep their browser meaning (new tab, new window, ...)
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;

    const mode = this.mode;
    if (mode === "view") return;

    const thumbnail = (event.target as Element).closest<HTMLElement>("article.thumbnail[data-id]");
    const post_id = Number(thumbnail?.dataset.id);
    if (!post_id) return;

    event.preventDefault();
    ACTIONS[mode](post_id);
  }
}

function toggle (element: HTMLElement | null, visible: boolean): void {
  if (element) element.style.display = visible ? "" : "none";
}
