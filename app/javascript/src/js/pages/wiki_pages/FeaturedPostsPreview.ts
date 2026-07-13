import ThumbnailEngine from "@/components/ThumbnailEngine";
import PostCache, { DeferredPostData } from "@/models/PostCache";
import Logger from "@/utility/Logger";

/**
 * Live preview for the wiki page "featured posts" input.
 * Validates the space-separated ID list client-side (mirroring WikiPage#validate_featured_posts)
 * and renders a thumbnail row so authors see the result before submitting.
 */
class FeaturedPostsPreview {
  private static Logger = new Logger("FeaturedPostsPreview");

  private static readonly DEBOUNCE_MS = 250;

  private static $input: JQuery<HTMLElement>;
  private static $wrapper: JQuery<HTMLElement>;
  private static $error: JQuery<HTMLElement>;
  private static $list: JQuery<HTMLElement>;
  private static max = 0;

  private static debounceTimer: ReturnType<typeof setTimeout> | null = null;
  private static requestID = 0;

  static init () {
    this.$wrapper = $("#featured-posts-preview");
    this.$input = $("#wiki_page_featured_posts_string");
    if (this.$wrapper.length === 0 || this.$input.length === 0) return;

    this.$error = this.$wrapper.find(".featured-posts-preview-error");
    this.$list = this.$wrapper.find(".featured-posts-preview-list");
    this.max = parseInt(this.$wrapper.data("max")) || 0;

    this.$input.on("input", () => {
      if (this.debounceTimer) clearTimeout(this.debounceTimer);
      this.debounceTimer = setTimeout(() => this.update(), this.DEBOUNCE_MS);
    });

    // Render whatever is already in the field on page load (relevant on edit).
    this.update();
  }

  // ============================== //
  // ======== Validation ========== //
  // ============================== //

  private static async update () {
    const requestID = ++this.requestID;
    const raw = String(this.$input.val() || "").trim();

    if (raw.length === 0) {
      this.clearError();
      this.clearList();
      return;
    }

    const tokens = raw.split(/\s+/);

    // 1. Non-numeric tokens
    const invalid = tokens.filter((token) => !/^\d+$/.test(token));
    if (invalid.length > 0) {
      this.showError(`Invalid post IDs: ${invalid.join(", ")}`);
      this.clearList();
      return;
    }

    const ids = tokens.map((token) => parseInt(token));

    // 2. Count limit
    if (this.max > 0 && ids.length > this.max) {
      this.showError(`Cannot have more than ${this.max} posts`);
      this.clearList();
      return;
    }

    // 3. Duplicates
    if (new Set(ids).size !== ids.length) {
      this.showError("Cannot contain duplicate posts");
      this.clearList();
      return;
    }

    this.clearError();
    await this.renderPosts(ids, requestID);
  }

  // ============================== //
  // ========= Rendering ========== //
  // ============================== //

  private static async renderPosts (ids: number[], requestID: number) {
    const uncached = ids.filter((id) => !PostCache.get(id));
    if (uncached.length > 0) {
      const posts = await this.fetchPosts(uncached);
      if (this.expired(requestID)) return;
      if (!posts) {
        this.showError("Failed to load posts");
        return;
      }
      for (const post of posts)
        PostCache.fromDeferredPosts(post.id, post, true);
    }

    if (this.expired(requestID)) return;

    // Any requested ID the API didn't return is nonexistent/unavailable.
    const missing = ids.filter((id) => !PostCache.get(id));
    if (missing.length > 0)
      this.showError(`Contains invalid post IDs: ${missing.join(", ")}`);

    this.clearList();
    for (const id of ids) {
      const post = PostCache.get(id);
      if (!post || post.isDeleted) continue;
      const thumbnail = ThumbnailEngine.render(post, { showStatistics: false, inline: true });
      if (thumbnail) this.$list.append(thumbnail);
    }
  }

  private static async fetchPosts (ids: number[]): Promise<DeferredPostData[] | null> {
    this.Logger.log("Fetching posts:", ids);
    try {
      const response = await fetch(`/posts.json?v2=true&mode=thumbnail&tags=id:${ids.join(",")}`);
      if (!response.ok) {
        console.error(`Failed to fetch posts: ${response.statusText}`);
        return null;
      }
      return await response.json();
    } catch (error) {
      console.error(`Error fetching posts: ${error}`);
      return null;
    }
  }

  // ============================== //
  // ========== Helpers =========== //
  // ============================== //

  private static expired (requestID: number) {
    return requestID !== this.requestID;
  }

  private static showError (message: string) {
    this.$error.text(message).attr("hidden", null);
  }

  private static clearError () {
    this.$error.text("").attr("hidden", "hidden");
  }

  private static clearList () {
    this.$list.find(".thumbnail").each((_, element) => { PostCache.prune($(element)); });
    this.$list.empty();
  }
}

$(() => {
  FeaturedPostsPreview.init();
});

export default FeaturedPostsPreview;
