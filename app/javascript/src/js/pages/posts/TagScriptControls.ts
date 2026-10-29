import PostCache from "@/models/PostCache";
import BulkActions from "@/pages/posts/BulkActions";
import TagScript, { TagScriptCommand, TagScriptError } from "@/pages/posts/TagScript";
import LStorage from "@/utility/storage/Local";
import ToastManager, { Toast } from "@/utility/Toast";

/** The index mode menu's tag script field, its 1-9 slots, and the "All" button. */
export default class TagScriptControls {

  private static field: HTMLInputElement | null = null;
  private static notice: Toast | null = null;

  static initialize (): void {
    this.field = document.querySelector<HTMLInputElement>("#tag-script-field");
    this.notice = null;
    if (!this.field) return;

    this.field.addEventListener("blur", () => {
      LStorage.Posts.TagScript.Content = this.field.value;
      this.parse(this.field.value);
    });
    document.getElementById("tag-script-all")?.addEventListener("click", (event) => {
      event.preventDefault();
      this.applyAll();
    });
  }

  /** Loads the current slot into the field. Announces the slot only when asked to. */
  static activate (announce: boolean): void {
    if (!this.field) return;
    this.field.value = LStorage.Posts.TagScript.Content;
    if (announce) this.announce();
  }

  static switchSlot (slot: number): void {
    if (!this.field || !Number.isInteger(slot) || slot < 1 || slot > 9) return;
    if (slot === LStorage.Posts.TagScript.ID) return;

    LStorage.Posts.TagScript.ID = slot;
    this.activate(true);
  }

  /** Applies the current script to a post. Pass pre-parsed `commands` to skip re-parsing. */
  static applyTo (post_id: number, commands?: TagScriptCommand[] | null): void {
    commands ??= this.parse(LStorage.Posts.TagScript.Content);
    const post = PostCache.get(post_id);
    if (!commands || !post) return;

    const changes = TagScript.evaluate(commands, post.tagSet);
    if (changes.length) BulkActions.applyTagDiff(post_id, changes, this.reason());
  }

  static applyAll (): void {
    const commands = this.parse(LStorage.Posts.TagScript.Content);
    if (!commands) return;

    const posts = Array.from(document.querySelectorAll<HTMLElement>("#posts article.thumbnail[data-id]"));
    const hidden = posts.filter((post) => post.classList.contains("blacklisted")).length;
    const note = hidden ? ` (${hidden} of them hidden by your blacklist)` : "";
    if (!confirm(`Apply the tag script to ${posts.length} posts${note}?`)) return;

    for (const post of posts) this.applyTo(Number(post.dataset.id), commands);
  }

  /** Returns the parsed commands, or null (with an alert) if the script is invalid */
  private static parse (script: string): TagScriptCommand[] | null {
    try {
      return TagScript.parse(script);
    } catch (error) {
      if (!(error instanceof TagScriptError)) throw error;
      ToastManager.alert(error.message);
      return null;
    }
  }

  private static reason (): string {
    return document.querySelector<HTMLInputElement>("#tag-script-reason")?.value ?? "";
  }

  private static announce (): void {
    this.notice?.dismiss(true);
    this.notice = ToastManager.create(`Switched to tag script #${LStorage.Posts.TagScript.ID}. To switch tag scripts, use the number keys.`);
  }
}
