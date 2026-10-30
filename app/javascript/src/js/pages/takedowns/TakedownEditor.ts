import Takedown, { TakedownAddResponse } from "@/models/Takedown";
import ToastManager from "@/utility/Toast";

/** Mirrors the limit in Takedown#add_posts_by_tags! */
const TAG_ADD_LIMIT = 1000;

/** Admin post list editor on takedowns#show: keep/delete toggles, adding and removing posts. */
export default class TakedownEditor {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: TakedownEditor | null = null;
  public static get instance (): TakedownEditor {
    if (!TakedownEditor._instance)
      TakedownEditor._instance = new TakedownEditor();
    return TakedownEditor._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private container: HTMLElement | null;
  private takedownId: number;

  private constructor () {
    if (TakedownEditor._instance)
      throw new Error("TakedownEditor is a singleton class. Use TakedownEditor.instance to access the instance.");

    this.container = document.querySelector<HTMLElement>("#takedown-posts");
    if (!this.container) return;
    this.takedownId = Number(this.container.dataset.takedownId);

    this.container.addEventListener("change", (event) => {
      const target = event.target as HTMLInputElement;
      if (target.matches("#takedown-post-buttons input[type=checkbox]")) this.syncLabel(target);
      if (target.type === "checkbox") this.refreshStatus();
    });

    this.container.addEventListener("click", (event) => {
      const button = (event.target as HTMLElement).closest<HTMLButtonElement>(".takedown-post-remove");
      if (button && !button.disabled) void this.removePost(button);
    });

    this.byId("takedown-keepall")?.addEventListener("click", () => this.setAll(false));
    this.byId("takedown-deleteall")?.addEventListener("click", () => this.setAll(true));

    this.bindInput("takedown-add-posts-tags", "takedown-add-posts-tags-preview");
    this.byId("takedown-add-posts-tags-preview")?.addEventListener("click", () => void this.previewTags());
    this.byId("takedown-add-posts-tags-confirm")?.addEventListener("click", () => void this.addByTags());
    this.byId("takedown-add-posts-tags-cancel")?.addEventListener("click", () => this.cancelTags());

    this.bindInput("takedown-add-posts-ids", "takedown-add-posts-ids-submit");
    this.byId("takedown-add-posts-ids-submit")?.addEventListener("click", () => void this.addByIds());

    this.refreshStatus();
  }

  /** Enables the button while the input has text; Enter clicks it instead of submitting the form */
  private bindInput (inputId: string, buttonId: string): void {
    const input = this.byId<HTMLInputElement>(inputId);
    const button = this.byId<HTMLButtonElement>(buttonId);
    if (!input || !button) return;

    input.addEventListener("input", () => { button.disabled = input.value.trim().length === 0; });
    input.addEventListener("keydown", (event) => {
      if (event.key !== "Enter") return;
      event.preventDefault();
      if (!button.disabled) button.click();
    });
  }


  /* ============================== */
  /* ======== Keep / delete ======= */
  /* ============================== */

  private get checkboxes (): HTMLInputElement[] {
    return Array.from(this.container.querySelectorAll<HTMLInputElement>("#takedown-post-buttons input[type=checkbox]"));
  }

  private setAll (remove: boolean): void {
    for (const checkbox of this.checkboxes) {
      checkbox.checked = remove;
      this.syncLabel(checkbox);
    }
    this.refreshStatus();
  }

  private syncLabel (checkbox: HTMLInputElement): void {
    const label = checkbox.closest("label");
    if (!label) return;
    label.classList.toggle("takedown-post-delete", checkbox.checked);
    label.classList.toggle("takedown-post-keep", !checkbox.checked);
    const span = label.querySelector("span");
    if (span) span.textContent = checkbox.checked ? "Delete" : "Keep";
  }

  /** Previews the status the takedown job will set, based on the kept/deleted split */
  private refreshStatus (): void {
    const status = document.getElementById("post-status-select");
    if (!status) return;

    const process = this.byId<HTMLInputElement>("process_takedown");
    const checkboxes = this.checkboxes;
    const deleted = checkboxes.filter((checkbox) => checkbox.checked).length;
    const kept = checkboxes.length - deleted;

    let text = "";
    if ((!process || process.checked) && checkboxes.length) {
      if (kept === 0) text = "Approved";
      else if (deleted === 0) text = "Denied";
      else text = "Partially Approved";
    }
    status.textContent = text ? `Status will be set to ${text}` : "";
  }


  /* ============================== */
  /* ========= Post list ========== */
  /* ============================== */

  private async removePost (button: HTMLButtonElement): Promise<void> {
    const row = button.closest<HTMLElement>(".takedown-post");
    const postId = Number(row?.dataset.postId);
    if (!postId) return;

    button.disabled = true;
    const result = await ToastManager.track(
      Takedown.removePost(this.takedownId, postId).then(() => true),
      `Removing post #${postId} from takedown...`,
      () => `Post #${postId} removed from takedown`,
    );
    if (!result) {
      button.disabled = false;
      return;
    }

    row.remove();
    this.refreshStatus();
  }

  private appendPosts (response: TakedownAddResponse): void {
    const list = this.byId("takedown-post-buttons");
    const template = document.querySelector<HTMLTemplateElement>("#takedown-post-template");
    if (!list || !template) return;

    for (const postId of response.added_post_ids) {
      if (document.getElementById(`takedown-post-${postId}`)) continue;
      list.append(TakedownEditor.buildRow(template, postId));
    }
    this.refreshStatus();
  }

  private static buildRow (template: HTMLTemplateElement, postId: number): HTMLElement {
    const row = template.content.firstElementChild.cloneNode(true) as HTMLElement;
    row.id = `takedown-post-${postId}`;
    row.dataset.postId = String(postId);

    row.querySelector("label").htmlFor = `takedown_posts_${postId}`;
    for (const input of row.querySelectorAll("input"))
      input.name = `takedown_posts[${postId}]`;
    row.querySelector<HTMLInputElement>("input[type=checkbox]").id = `takedown_posts_${postId}`;

    const link = row.querySelector("a");
    link.href = `/posts/${postId}`;
    link.textContent = `post #${postId}`;
    return row;
  }

  private static addedText (response: TakedownAddResponse): string {
    const count = response.added_count;
    return `${count} post${count === 1 ? "" : "s"} added to takedown`;
  }


  /* ============================== */
  /* ======== Add by tags ========= */
  /* ============================== */

  private async previewTags (): Promise<void> {
    const input = this.byId<HTMLInputElement>("takedown-add-posts-tags");
    const button = this.byId<HTMLButtonElement>("takedown-add-posts-tags-preview");
    const tags = input.value.trim();
    if (!tags) return;

    button.disabled = true;
    let count: number;
    try {
      count = await Takedown.countMatchingPosts(tags);
    } catch {
      button.disabled = false;
      return; // Reported by ApiRequest
    }

    this.byId("takedown-add-posts-tags-warning").replaceChildren(...TakedownEditor.previewNodes(tags, count));
    this.setTagsPreviewing(true);
  }

  private static previewNodes (tags: string, count: number): (Node | string)[] {
    const href = `/posts?${new URLSearchParams({ tags: `${tags} -status:deleted` })}`;
    const link = (text: string) => {
      const anchor = document.createElement("a");
      anchor.href = href;
      anchor.textContent = text;
      return anchor;
    };

    const one = count === 1;
    const nodes: (Node | string)[] = [
      link(`${count} ${one ? "post" : "posts"}`),
      ` ${one ? "matches" : "match"} the search '`,
      link(tags),
      `'. Click Confirm to add ${one ? "it" : "them"} to the takedown.`,
    ];
    if (count > TAG_ADD_LIMIT) nodes.push(` Only the first ${TAG_ADD_LIMIT} will be added.`);
    return nodes;
  }

  private async addByTags (): Promise<void> {
    const tags = this.byId<HTMLInputElement>("takedown-add-posts-tags").value.trim();
    const confirm = this.byId<HTMLButtonElement>("takedown-add-posts-tags-confirm");

    confirm.disabled = true;
    const response = await ToastManager.track(
      Takedown.addPostsByTags(this.takedownId, tags),
      "Adding posts to takedown...",
      TakedownEditor.addedText,
    );
    confirm.disabled = false;
    if (!response) return;

    this.appendPosts(response);
    this.cancelTags();
  }

  private cancelTags (): void {
    const input = this.byId<HTMLInputElement>("takedown-add-posts-tags");
    input.value = "";
    this.byId<HTMLButtonElement>("takedown-add-posts-tags-preview").disabled = true;
    this.byId("takedown-add-posts-tags-warning").replaceChildren();
    this.setTagsPreviewing(false);
  }

  private setTagsPreviewing (previewing: boolean): void {
    this.byId<HTMLInputElement>("takedown-add-posts-tags").disabled = previewing;
    this.byId("takedown-add-posts-tags-preview").hidden = previewing;
    this.byId("takedown-add-posts-tags-confirm").hidden = !previewing;
    this.byId("takedown-add-posts-tags-cancel").hidden = !previewing;
    this.byId("takedown-add-posts-tags-warning").hidden = !previewing;
  }


  /* ============================== */
  /* ========= Add by IDs ========= */
  /* ============================== */

  private async addByIds (): Promise<void> {
    const input = this.byId<HTMLInputElement>("takedown-add-posts-ids");
    const button = this.byId<HTMLButtonElement>("takedown-add-posts-ids-submit");
    const ids = input.value.trim();
    if (!ids) return;

    button.disabled = true;
    const response = await ToastManager.track(
      Takedown.addPostsByIds(this.takedownId, ids),
      "Adding posts to takedown...",
      TakedownEditor.addedText,
    );
    if (!response) {
      button.disabled = false;
      return;
    }

    this.appendPosts(response);
    input.value = "";
  }


  private byId<T extends HTMLElement = HTMLElement> (id: string): T | null {
    return this.container.querySelector<T>(`#${id}`);
  }
}
