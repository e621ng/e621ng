import HTTP from "@/utility/HTTP";
import LStorage from "@/utility/storage/Local";
import TaskQueue from "@/utility/TaskQueue";
import ToastManager, { Toast } from "@/utility/Toast";

type SetAction = "add" | "remove";

/** `/post_sets/for_select.json`: `[label, id]` tuples grouped by relationship to the user */
export interface ForSelectResponse {
  Owned: [string, number][];
  Maintained: [string, number][];
}

/**
 * Post set API shared by posts#show (dialog, remove links) and the posts#index mode menu.
 * Single-post calls are batched per set and flushed together to keep request counts down.
 */
export default class PostSet {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: PostSet | null = null;
  public static get instance (): PostSet {
    if (!PostSet._instance)
      PostSet._instance = new PostSet();
    return PostSet._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private constructor () {
    if (PostSet._instance)
      throw new Error("PostSet is a singleton class. Use PostSet.instance to access the instance.");

    // The "remove from set" buttons in the posts#show set navigation blocks
    $("a.set-nav-remove-link").on("click", (event) => {
      event.preventDefault();
      const { setId, postId } = (event.currentTarget as HTMLElement).dataset;
      PostSet.remove_post(Number(setId), Number(postId));
    });
  }

  private static postUpdateToast: Toast | null = null;

  private static timeouts: Record<SetAction, number | null> = { add: null, remove: null };
  private static caches: Record<SetAction, Map<number, Set<number>>> = { add: new Map(), remove: new Map() };

  /** Queues the post for addition to the set; flushed with other pending posts after a short delay */
  static add_post (set_id: number | string, post_id: number): void {
    PostSet.queue("add", set_id, post_id);
  }

  /** Queues the post for removal from the set; flushed with other pending posts after a short delay */
  static remove_post (set_id: number | string, post_id: number): void {
    PostSet.queue("remove", set_id, post_id);
  }

  /** Adds the posts to the set in one request */
  static add_many_posts (set_id: number, posts: number[] = []): Promise<void> | void {
    return PostSet.sendMany("add", set_id, posts);
  }

  /** Removes the posts from the set in one request */
  static remove_many_posts (set_id: number, posts: number[] = []): Promise<void> | void {
    return PostSet.sendMany("remove", set_id, posts);
  }

  private static queue (action: SetAction, set_id: number | string, post_id: number): void {
    const setId = Number(set_id);
    if (!setId) return ToastManager.alert("Error: No set specified");

    if (!this.postUpdateToast)
      this.postUpdateToast = ToastManager.create("Updating posts...", { timeout: 0 });

    const cache = this.caches[action];
    let posts = cache.get(setId);
    if (!posts) {
      posts = new Set();
      cache.set(setId, posts);
    }
    posts.add(post_id);
    this.postUpdateToast.message = `Updating posts (${posts.size} pending)`;

    if (this.timeouts[action]) window.clearTimeout(this.timeouts[action]);
    this.timeouts[action] = window.setTimeout(() => this.flush(action), 1000);
  }

  private static flush (action: SetAction): void {
    const cache = this.caches[action];
    for (const [setId, posts] of cache)
      void PostSet.sendMany(action, setId, [...posts]);
    cache.clear();
    this.timeouts[action] = null;
  }

  private static sendMany (action: SetAction, set_id: number, posts: number[]): Promise<void> | void {
    if (!set_id) return ToastManager.alert("Error: No set specified");
    if (typeof set_id !== "number" || isNaN(set_id)) return ToastManager.alert("Error: Invalid set specified");

    return TaskQueue.add(async () => {
      const body = new URLSearchParams();
      for (const id of posts) body.append("post_ids[]", String(id));

      let response: Response;
      try {
        response = await HTTP.post(`/post_sets/${set_id}/${action}_posts.json`, body);
      } catch {
        return this.fail("Request failed");
      }
      if (!response.ok) return this.fail(await HTTP.errorMessage(response));

      if (!this.postUpdateToast) this.postUpdateToast = ToastManager.create("Updating posts...", { timeout: 0 });
      const count = posts.length > 1 ? `${posts.length} posts` : "post";
      this.postUpdateToast.message = action === "add"
        ? `Added ${count} to <a href="/post_sets/${set_id}">set #${set_id}</a>`
        : `Removed ${count} from <a href="/post_sets/${set_id}">set #${set_id}</a>`;
      this.postUpdateToast.timeout = 3;
      this.postUpdateToast = null;
    }, { name: `PostSet.${action}_many_posts` });
  }

  private static fail (message: string): void {
    ToastManager.alert("Error: " + message);
    this.postUpdateToast?.dismiss(true);
    this.postUpdateToast = null;
  }


  /* ============================== */
  /* ========= Set picker ========= */
  /* ============================== */

  static async fetchForSelect (): Promise<ForSelectResponse> {
    const response = await HTTP.get("/post_sets/for_select.json");
    if (!response.ok) throw new Error(await HTTP.errorMessage(response));
    return response.json();
  }

  /**
   * Fills the select with the user's sets, grouped by Owned / Maintained,
   * preselecting the last used set and remembering changes.
   */
  static async populateSelect (select: JQuery<HTMLSelectElement>): Promise<void> {
    select.empty().append($("<option>").text("Loading...")).off("change");

    let data: ForSelectResponse;
    try {
      data = await PostSet.fetchForSelect();
    } catch (error) {
      ToastManager.alert("Error getting sets list: " + ((error as Error)?.message || "unknown error"));
      return;
    }

    const stored = Number(LStorage.Posts.Set);
    select.empty();
    for (const label of ["Owned", "Maintained"] as const) {
      const group = $("<optgroup>").attr("label", label);
      for (const [name, id] of data[label] ?? [])
        group.append($("<option>").val(id).text(name).prop("selected", id === stored));
      select.append(group);
    }

    select.on("change", (event) => {
      const value = Number((event.target as HTMLSelectElement).value);
      if (isNaN(value)) {
        ToastManager.alert("Error: Invalid set specified");
        return;
      }
      LStorage.Posts.Set = value;
    });
  }

}
