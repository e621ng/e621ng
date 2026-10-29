import Rails from "@rails/ujs";
import Hotkeys from "@/core/hotkeys";
import Post from "@/models/Post";
import PostCache from "@/models/PostCache";
import BulkActions from "@/pages/posts/BulkActions";
import PendingUpdates from "@/pages/posts/PendingUpdates";
import ToastManager from "@/utility/Toast";

const MIN_HEIGHT = 80;

/** The inline tag editor opened by the index mode menu's "Edit" mode. */
export default class QuickEdit {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: QuickEdit | null = null;
  public static get instance (): QuickEdit {
    if (!QuickEdit._instance)
      QuickEdit._instance = new QuickEdit();
    return QuickEdit._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private container: HTMLElement | null;
  private form: HTMLFormElement | null;
  private textarea: HTMLTextAreaElement | null;

  private _postID: number | null = null;
  // The tags the user started from, so the server merges concurrent edits instead of reverting them
  private oldTagString = "";

  private constructor () {
    if (QuickEdit._instance)
      throw new Error("QuickEdit is a singleton class. Use QuickEdit.instance to access the instance.");

    this.container = document.getElementById("quick-edit-div");
    this.form = document.querySelector<HTMLFormElement>("#quick-edit-form");
    this.textarea = document.querySelector<HTMLTextAreaElement>("#post_tag_string");
    if (!this.container || !this.form || !this.textarea) return;

    this.form.addEventListener("submit", (event) => {
      event.preventDefault();
      this.submit();
    });
    document.getElementById("quick-edit-cancel")?.addEventListener("click", (event) => {
      event.preventDefault();
      this.close();
    });
    // Listening on the form lets an open autocomplete dropdown consume Escape first
    this.form.addEventListener("keydown", (event) => {
      if (event.key !== "Escape" || event.defaultPrevented) return;
      event.preventDefault();
      this.close();
    });
  }

  /** ID of the post being edited, or null if the editor is closed */
  public get postID (): number | null { return this._postID; }

  public open (post_id: number): void {
    const post = PostCache.get(post_id);
    if (!this.container || !this.textarea || !post) return;

    this._postID = post_id;
    this.oldTagString = post.tag_string;
    Hotkeys.enabled = false;

    this.container.classList.add("open");
    this.container.removeAttribute("inert");

    const textarea = this.textarea;
    textarea.value = post.tag_string + " ";
    textarea.focus();
    textarea.setSelectionRange(textarea.value.length, textarea.value.length);

    // Fit the content height (content-box sizing, so padding is excluded)
    textarea.style.height = MIN_HEIGHT + "px";
    const style = getComputedStyle(textarea);
    const padding = (parseFloat(style.paddingTop) || 0) + (parseFloat(style.paddingBottom) || 0);
    textarea.style.height = Math.max(MIN_HEIGHT, textarea.scrollHeight - padding) + "px";
  }

  public close (): void {
    if (this._postID === null) return;
    this._postID = null;

    // AutocompleteWidget closes its dropdown on blur
    this.textarea?.blur();
    this.container?.classList.remove("open");
    this.container?.setAttribute("inert", "");
    Hotkeys.enabled = true;
  }

  private submit (): Promise<void> {
    const post_id = this._postID;
    if (post_id === null) return Promise.resolve();

    const params = { tag_string: this.textarea.value, old_tag_string: this.oldTagString };
    return PendingUpdates.track(Post.update(post_id, params))
      .then((data) => {
        BulkActions.syncThumbnail(data);
        ToastManager.notice(`Post #${data.id} updated`);
        if (this._postID === post_id) this.close();
      })
      .catch(() => { /* Reported through danbooru:error */ })
      .finally(() => { Rails.enableElement(this.form); });
  }
}
