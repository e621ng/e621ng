import Filter from "@/core/blacklist/Filter";
import CurrentUser from "@/models/CurrentUser";
import PostCache, { CachedPost } from "@/models/PostCache";
import LStorage from "@/utility/storage/Local";
import BlacklistWidget from "./BlacklistWidget";
import CommentBlacklist from "./CommentBlacklist";

/**
 * Decides which posts on the page are hidden by the user's blacklist.
 *
 * Thumbnails are tracked by PostCache; this class only listens. Any change
 * (new thumbnail, edited attributes, filter toggled, blacklist edited) marks
 * the affected posts dirty and schedules a single commit in a microtask.
 * The commit re-evaluates the dirty posts, diffs the hidden / matched sets,
 * updates the classes, and announces the result through `e621:blacklist:changed`.
 */
class Blacklist {

  /* ============================== */
  /* ===== Singleton Pattern ====== */
  /* ============================== */

  private static _instance: Blacklist = null;
  public static get instance (): Blacklist {
    if (!this._instance) this._instance = new Blacklist();
    return this._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  public filters: Record<string, Filter> = {};

  /** Posts hidden right now. Replaced, never mutated, on every commit. */
  public hiddenPosts = new Set<number>();
  /** Posts matching any filter, enabled or not. Replaced on every commit. */
  public matchedPosts = new Set<number>();

  private revealed = new Set<number>();
  private dirty: Set<number> | "all" = "all";
  private pending = new Set<HTMLElement>();
  private scheduled = false;
  private warned = new Set<string>();

  private constructor () {
    if (Blacklist._instance)
      throw new Error("Blacklist is a singleton class. Use Blacklist.instance to access the instance.");

    this.regenerateFilters();

    PostCache.on("post:added", ({ elements }) => {
      for (const element of elements) {
        this.pending.add(element);
        this.markDirty(parseInt(element.dataset.id) || 0);
      }
      this.schedule();
    });
    PostCache.on("post:changed", ({ ids }) => {
      for (const id of ids) this.markDirty(id);
      this.schedule();
    });
    PostCache.on("post:removed", ({ ids }) => {
      for (const id of ids) {
        for (const filter of Object.values(this.filters)) filter.forget(id);
        this.revealed.delete(id);
        if (this.dirty !== "all") this.dirty.delete(id);
      }
      this.schedule();
    });

    document.addEventListener("e621:blacklistUpdated", () => {
      this.regenerateFilters();
      this.invalidate("all");
    });

    $(() => this.onDOMLoad());

    // PostCache has already swept the page by the time this runs
    this.schedule();
  }

  private onDOMLoad () {
    this.flush();
    BlacklistWidget.initializeAll();
    CommentBlacklist.initializeAll();
  }


  /* ============================== */
  /* ========= Public API ========= */
  /* ============================== */

  /**
   * Marks posts for re-evaluation on the next commit.
   * @param ids Posts to re-evaluate, `"all"` for every post on the page, or nothing to only recompute the sets
   */
  public invalidate (ids?: Iterable<number> | "all"): void {
    if (ids === "all") this.dirty = "all";
    else if (ids) for (const id of ids) this.markDirty(id);
    this.schedule();
  }

  /** Runs the pending commit right away. No-op when nothing changed. */
  public flush (): void {
    if (!this.scheduled) return;
    this.scheduled = false;
    this.commit();
  }

  /**
   * Shows a hidden post until it stops being hidden by the filters
   * (e.g. the filter is toggled off and on again).
   */
  public reveal (id: number): void {
    this.revealed.add(id);
    this.invalidate();
  }

  /** Enables or disables every filter at once, with a single storage write. */
  public setAllEnabled (enabled: boolean): void {
    const disabled = new Set<string>();
    for (const filter of Object.values(this.filters)) {
      filter.setEnabledWithoutSaving(enabled);
      if (!enabled) disabled.add(filter.text);
    }
    LStorage.Blacklist.FilterState = disabled;
    this.invalidate();
  }


  /* ============================== */
  /* ========== Commit ============ */
  /* ============================== */

  private markDirty (id: number): void {
    if (!id || this.dirty === "all") return;
    this.dirty.add(id);
  }

  private schedule (): void {
    if (this.scheduled) return;
    this.scheduled = true;
    queueMicrotask(() => this.flush());
  }

  private commit (): void {
    const filters = Object.values(this.filters);

    // 1. Re-evaluate whatever changed
    const everything = this.dirty === "all";
    let ids: number[];
    if (this.dirty === "all") {
      for (const filter of filters) filter.matchIDs.clear();
      ids = PostCache.ids();
    } else ids = Array.from(this.dirty);

    for (const id of ids) {
      const post: CachedPost | null = PostCache.get(id);
      for (const filter of filters) {
        if (post) filter.updateWithPosts(post);
        else filter.forget(id);
      }
    }

    // 2. Rebuild the sets
    const rawHidden = new Set<number>();
    const matched = new Set<number>();
    for (const filter of filters) {
      for (const id of filter.matchIDs) matched.add(id);
      if (!filter.enabled) continue;
      for (const id of filter.matchIDs) rawHidden.add(id);
    }

    // A reveal only lasts while the filters keep hiding the post
    for (const id of this.revealed)
      if (!rawHidden.has(id)) this.revealed.delete(id);
    const hidden = new Set<number>();
    for (const id of rawHidden)
      if (!this.revealed.has(id)) hidden.add(id);

    const previousHidden = this.hiddenPosts;
    const previousMatched = this.matchedPosts;
    const added = Array.from(hidden).filter((id) => !previousHidden.has(id));
    const removed = Array.from(previousHidden).filter((id) => !hidden.has(id));

    this.hiddenPosts = hidden;
    this.matchedPosts = matched;
    this.dirty = new Set();
    this.scheduled = false;

    // 3. New elements (and every element, after a full re-evaluation) get their
    //    complete state, and shed the pre-JS hiding class
    const fresh = new Set<HTMLElement>();
    const applyState = (element: HTMLElement, isNew: boolean) => {
      if (!element.isConnected || fresh.has(element)) return;
      fresh.add(element);

      const id = parseInt(element.dataset.id) || 0;
      const wasHidden = previousHidden.has(id);
      const isHidden = hidden.has(id);
      const $element = $(element)
        .toggleClass("blacklisted", isHidden)
        .toggleClass("filter-matches", matched.has(id))
        .removeClass("blacklistable");
      if (isHidden && (isNew || !wasHidden)) $element.trigger("blk:hide");
      else if (!isHidden && wasHidden && !isNew) $element.trigger("blk:show");
    };
    for (const element of this.pending) applyState(element, true);
    this.pending.clear();
    if (everything)
      for (const id of ids) PostCache.apply(id, ($el) => applyState($el[0], false));

    // 4. Everything else only gets the diff
    const skipFresh = (fn: ($el: JQuery<HTMLElement>) => void) => ($el: JQuery<HTMLElement>) => {
      if (!fresh.has($el[0])) fn($el);
    };
    for (const id of added)
      PostCache.apply(id, skipFresh(($el) => { $el.addClass("blacklisted").trigger("blk:hide"); }));
    for (const id of removed)
      PostCache.apply(id, skipFresh(($el) => { $el.removeClass("blacklisted").trigger("blk:show"); }));
    for (const id of matched)
      if (!previousMatched.has(id)) PostCache.apply(id, skipFresh(($el) => { $el.addClass("filter-matches"); }));
    for (const id of previousMatched)
      if (!matched.has(id)) PostCache.apply(id, skipFresh(($el) => { $el.removeClass("filter-matches"); }));

    document.dispatchEvent(new CustomEvent<BlacklistChangedDetail>("e621:blacklist:changed", {
      detail: { hidden, matched, added, removed },
    }));
  }


  /* ============================== */
  /* ======== Class Methods ======= */
  /* ============================== */

  /** Import the blacklist from the meta tag */
  private regenerateFilters () {
    this.filters = {};

    // Attempt to create filters from text
    for (const entry of CurrentUser.blacklist) {
      const line = Filter.create(entry);
      if (!line) continue;
      line.onChange = () => this.invalidate();
      this.filters[line.text] = line;
    }

    // Clear any FilterState entries that don't have a matching filter
    const keys = Object.keys(this.filters);
    for (const filterState of LStorage.Blacklist.FilterState) {
      if (keys.includes(filterState)) continue;
      LStorage.Blacklist.FilterState.delete(filterState);
    }
  }


  /* ============================== */
  /* ======== Deprecated API ====== */
  /* ============================== */
  // Thumbnails are tracked automatically now. These stay for userscripts
  // that reach them through `E621.Blacklist`.
  // TODO: Remove after November 2026

  private deprecated (name: string): void {
    if (this.warned.has(name)) return;
    this.warned.add(name);
    console.warn(`Blacklist.${name}() is deprecated: thumbnails are tracked automatically. Call Blacklist.flush() if you need a synchronous update.`);
  }

  public addPosts ($posts: JQuery<HTMLElement> | JQuery<HTMLElement>[]) {
    this.deprecated("addPosts");
    PostCache.register($posts);
    this.flush();
  }

  public refreshPosts ($posts: JQuery<HTMLElement>) {
    this.deprecated("refreshPosts");
    PostCache.register($posts, true);
    this.flush();
  }

  public loadDeferredPosts (posts: CachedPost | CachedPost[]) {
    this.deprecated("loadDeferredPosts");
    this.invalidate((Array.isArray(posts) ? posts : [posts]).map((post) => post.id));
    this.flush();
  }

  public updatePostVisibility () {
    this.deprecated("updatePostVisibility");
    this.invalidate();
    this.flush();
  }

  public recalculateMatchedPosts () {
    this.deprecated("recalculateMatchedPosts");
    this.invalidate("all");
    this.flush();
  }

  public updateThumbnailStyles () {
    this.deprecated("updateThumbnailStyles");
    this.invalidate();
    this.flush();
  }
}

export interface BlacklistChangedDetail {
  hidden: Set<number>;
  matched: Set<number>;
  added: number[];
  removed: number[];
}

export default Blacklist.instance;
