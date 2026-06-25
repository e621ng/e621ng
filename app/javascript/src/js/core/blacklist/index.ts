import Filter from "@/core/blacklist/Filter";
import CurrentUser from "@/models/CurrentUser";
import PostCache, { CachedPost } from "@/models/PostCache";
import LStorage from "@/utility/storage/Local";
import BlacklistWidget from "./BlacklistWidget";
import CommentBlacklist from "./CommentBlacklist";

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

  private isPostsShow = false;
  public filters: Record<string, Filter> = {};

  public hiddenPosts = new Set<number>();
  public matchedPosts = new Set<number>();

  private constructor () {
    if (Blacklist._instance)
      throw new Error("BlacklistManager is a singleton class. Use BlacklistManager.instance to access the instance.");

    this.regenerateFilters();
    $(() => this.onDOMLoad());

    document.addEventListener("e621:blacklistUpdated", () => {
      this.regenerateFilters();
      this.addPosts(PostCache.sample());
      this.updatePostVisibility();
    });
  }

  private onDOMLoad () {
    this.isPostsShow = $("#image-container").length > 0;

    this.addPosts($(".blacklistable"));
    this.updateThumbnailStyles();
    this.updatePostVisibility();
    $("#blacklisted-hider").remove();

    BlacklistWidget.initializeAll();
    CommentBlacklist.initializeAll();

    // Pause videos when blacklisting
    // This seems extraordinarily uncommon, so it's here
    // just for feature parity with the old blacklist.
    if (!this.isPostsShow) return;
    const container = $("#image-container[data-file-ext='mp4'], \
                      #image-container[data-file-ext='webm']")
      .on("blk:hide", () => {
        const video = container.find("video");
        if (!video.length) return;
        video[0].pause();
      });
  }


  /* ============================== */
  /* ========= Public API ========= */
  /* ============================== */

  /**
   * Recalculate hidden posts based on the current filters.
   * Also applies or removed `blacklist` class wherever necessary.
   */
  public updatePostVisibility () {
    const oldPosts = [...this.hiddenPosts];
    let newPosts = [];

    // Tally up the new blacklisted posts
    for (const filter of Object.values(this.filters)) {
      if (!filter.enabled) continue;
      newPosts = newPosts.concat(Array.from(filter.matchIDs));
    }

    // Calculate diffs
    // TODO I feel like this could be optimized.
    this.hiddenPosts = new Set(newPosts.filter(n => n));
    const added = [...this.hiddenPosts].filter((n) => !oldPosts.includes(n));
    const removed = oldPosts.filter((n) => !this.hiddenPosts.has(n));

    // Update the UI
    $(document).trigger("e621:blacklist:state-changed");

    // Apply / remove classes
    // TODO: Cache the post elements to avoid repeat lookups
    for (const postID of added)
      PostCache.apply(postID, ($element) => {
        $element.addClass("blacklisted").trigger("blk:hide");
      });
    for (const postID of removed)
      PostCache.apply(postID, ($element) => {
        $element.removeClass("blacklisted").trigger("blk:show");
      });

    // Toggle notes on the posts#show page
    if (!this.isPostsShow) return;

    const container = $("#image-container");
    if (container.hasClass("blacklisted")) {
      $("#note-container").css("visibility", "hidden");
    } else {
      $("#note-container").css("visibility", "visible");
    }
  }

  /**
   * Register posts in the system, and calculate which filters apply to them
   * @param {JQuery<HTMLElement> | JQuery<HTMLElement>[]} $posts Posts to register
   */
  public addPosts ($posts: JQuery<HTMLElement> | JQuery<HTMLElement>[]) {
    const newElements = PostCache.register($posts);

    for (const filter of Object.values(this.filters))
      filter.updateWithElements($posts);

    // Immediately apply the blacklist class to any newly registered elements that are already hidden.
    // updatePostVisibility() does not apply the class to posts whose status did not change.
    for (const $element of newElements) {
      const id = $element.data("id");
      if (this.hiddenPosts.has(id))
        $element.addClass("blacklisted").trigger("blk:hide");
    }
  }

  /**
   * Loads posts into the blacklist system, updating the filters with any new matches.
   * @param {CachedPost | CachedPost[]} posts Posts to load into the blacklist system
   */
  public loadDeferredPosts (posts: CachedPost | CachedPost[]) {
    for (const filter of Object.values(this.filters))
      filter.updateWithPosts(posts);
  }

  /**
   * Adds a `filter-matches` class to any thumbnails that match any of the filters,
   * including disabled ones. Only needs to run after new posts get added to the page.
   */
  public updateThumbnailStyles () {
    let allPosts = [];
    for (const filter of Object.values(this.filters))
      allPosts = allPosts.concat(Array.from(filter.matchIDs));
    this.matchedPosts = new Set(allPosts);

    $(".filter-matches").removeClass("filter-matches");
    for (const postID of this.matchedPosts)
      PostCache.apply(postID, ($element) => {
        $element.addClass("filter-matches");
      });
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
      if (line) this.filters[line.text] = line;
    }

    // Clear any FilterState entries that don't have a matching filter
    const keys = Object.keys(this.filters);
    for (const filterState of LStorage.Blacklist.FilterState) {
      if (keys.includes(filterState)) continue;
      LStorage.Blacklist.FilterState.delete(filterState);
    }
  }
}

export default Blacklist.instance;
