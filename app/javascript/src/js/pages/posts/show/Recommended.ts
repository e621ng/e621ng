import Analytics from "@/core/Analytics";
import ThumbnailEngine from "@/components/ThumbnailEngine";
import CurrentPost from "@/models/CurrentPost";
import PostCache, { CachedPost, DeferredPostData } from "@/models/PostCache";
import HTTP from "@/utility/HTTP";
import Logger from "@/utility/Logger";
import PerformanceTracker from "@/utility/PerformanceTracker";
import CStorage from "@/utility/storage/Cookie";
import LStorage from "@/utility/storage/Local";

export type RecommendationAction = "artist" | "tags";
export type RecommendationStatus = "waiting" | "loading" | "ready" | "error";

export interface RecommendationResult {
  post_id: number;
  score: number;
  explanation: string | null;
}

/** Payload from PostRecommendationsController */
export interface RecommendationResponse {
  post_id: number;
  model_version: string;
  results: RecommendationResult[];
  post_data?: DeferredPostData[];
}

/** Normalised form kept per tab, so switching back does not refetch */
interface CachedRecommendations {
  results: Record<number, RecommendationResult>;
  order: number[];
}

const ALL_ACTIONS: RecommendationAction[] = ["artist", "tags"];

/**
 * The "From the Artist" / "Similar" recommendations strip at the bottom of posts#show.
 * Loads lazily once scrolled into view, caches each tab's results, and renders
 * thumbnails through ThumbnailEngine so the blacklist applies to them.
 */
export default class Recommended {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: Recommended | null = null;
  public static get instance (): Recommended {
    if (!Recommended._instance)
      Recommended._instance = new Recommended();
    return Recommended._instance;
  }

  public static readonly RESULT_COUNT = 6;


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private Logger = new Logger("Recommended");

  private wrapper: JQuery<HTMLElement>;
  private container: JQuery<HTMLElement>;
  private toggle: JQuery<HTMLElement>;

  private validActions: RecommendationAction[] = [];
  private initialized = false; // Set once the section has scrolled into view
  private requestID = 0;
  private recommendationCache = new Map<RecommendationAction, CachedRecommendations>();

  private constructor () {
    if (Recommended._instance)
      throw new Error("Recommended is a singleton class. Use Recommended.instance to access the instance.");

    this.wrapper = $("#post-recommendations");
    this.container = $("#post-recommendations-list");
    this.toggle = $("#post-recommendations-toggle button");
    if (!this.container.length) return;

    // Only the tabs the server rendered are available
    this.validActions = ALL_ACTIONS.filter((action) => $(`#post-recommendations-tab-${action}`).length > 0);
    if (this.validActions.length === 0) {
      this.Logger.log("No valid recommendation states available.");
      this.wrapper.hide();
      return;
    }

    const initialAction = this.action;
    this.action = initialAction;
    this.Logger.log(
      "Loaded",
      `\n ⤷ Initial Action: ${initialAction}`,
      `\n ⤷ Valid Actions: ${this.validActions.join(", ")}`,
    );

    // Only the first click is tracked; the link navigates away regardless.
    if (Analytics.enabled)
      this.wrapper.one("click", "a", (event) => {
        const target = event.currentTarget.dataset.target;
        if (!target) return;
        Analytics.track("recommendation", {
          target: "/posts/" + target,
          action: this.action,
        });
      });

    this.waitUntilReady().then(() => {
      this.initialized = true;
      this.loadState();
    });

    this.wrapper.find("#post-recommendations-tabs").on("click", "button", (event) => {
      if (!this.initialized) return;
      this.action = $(event.currentTarget).data("action");
      this.loadState(this.action);
    });

    this.toggle.on("click", () => {
      this.visible = !this.visible;
    });
  }


  /* ============================== */
  /* ===== Getters / Setters ====== */
  /* ============================== */

  public get action (): RecommendationAction {
    const stored = LStorage.Posts.Recommendations;
    return this.validActions.includes(stored) ? stored : this.validActions[0];
  }

  public set action (value: RecommendationAction) {
    if (!this.validActions.includes(value))
      value = this.validActions[0];

    LStorage.Posts.Recommendations = value;
    this.wrapper.attr("data-action", value);
    this.wrapper.find("#post-recommendations-tabs button").each((_, button) => {
      $(button).attr("aria-selected", $(button).data("action") === value ? "true" : "false");
    });
    this.container.attr("aria-labelledby", `post-recommendations-tab-${value}`);
  }

  public get status (): RecommendationStatus {
    return (this.wrapper.attr("data-status") as RecommendationStatus) || "waiting";
  }

  public set status (value: RecommendationStatus) {
    this.wrapper.attr("data-status", value);
  }

  public get visible (): boolean {
    return !CStorage.Posts.SimilarHidden;
  }

  public set visible (value: boolean) {
    CStorage.Posts.SimilarHidden = !value;
    this.wrapper.attr("data-visible", value ? "true" : "false");
    this.toggle.attr({
      "aria-expanded": value ? "true" : "false",
      "aria-label": value ? "Hide Recommendations" : "Show Recommendations",
    });
  }


  /* ============================== */
  /* ====== State Management ====== */
  /* ============================== */

  public async loadState (action: RecommendationAction = this.action): Promise<void> {
    const requestID = ++this.requestID;
    const requestExpired = () => requestID !== this.requestID;

    const perf = new PerformanceTracker(`loadState-${action}-${requestID}`);
    const measurePerformance = () => {
      perf.mark("end");

      const output = [`Loaded in ${perf.measurePretty("start", "end")}`];
      if (perf.hasMark("data-fetched"))
        output.push(`\n ⤷ Data fetched in ${perf.measurePretty("start", "data-fetched")}`);
      if (perf.hasMark("posts-fetched"))
        output.push(`\n ⤷ Posts fetched in ${perf.measurePretty("data-fetched", "posts-fetched")}`);
      if (perf.hasMark("rendered"))
        output.push(`\n ⤷ Rendered in ${perf.measurePretty("posts-fetched", "rendered")}`);

      this.Logger.log(...output);
      perf.clear();
    };

    this.Logger.log(`Loading state: "${action}" (Req ID: ${requestID})`);
    const container = this.container;

    if (!this.validActions.includes(action)) {
      if (this.validActions.length === 0) {
        this.Logger.log("No valid recommendation states available.");
        this.status = "error";
        container.html("<p class='error'>No recommendations available.</p>");
        return;
      }
      action = this.validActions[0];
      this.action = action;
    }

    // 1. Render skeleton placeholders.
    // On first load the server-rendered placeholders are still in place and reused.
    if (this.status !== "waiting") {
      this.status = "waiting";

      container.empty();

      for (let i = 0; i < Recommended.RESULT_COUNT; i++)
        container.append(ThumbnailEngine.renderPlaceholder());
    }

    // 2. Fetch recommendations data
    this.status = "loading";
    let data = this.recommendationCache.get(action);
    if (!data) {
      const response = await this.getData(action);
      if (!response || !response.results) {
        measurePerformance();
        if (requestExpired()) return;
        this.status = "error";
        container.html("<p class='error'>Failed to load recommendations.</p>");
        return;
      }

      // The local recommender includes thumbnail data; the remote service does not.
      if (response.post_data) {
        this.Logger.log("Found included post data", response.post_data);
        this.setCachedPosts(response.post_data);
        this.Logger.log("Cache state:", PostCache.stats());
      }

      data = { results: {}, order: [] };
      for (const result of response.results) {
        data.results[result.post_id] = result;
        data.order.push(result.post_id);
      }

      this.recommendationCache.set(action, data);
      perf.mark("data-fetched");
    } else {
      this.Logger.log("Using cached recommendations:", data);
      perf.mark("data-fetched", "cached");
    }

    // 3. Fetch post data for recommended posts
    let posts = this.getCachedPosts(data.order);
    const missingPostIds = data.order.filter((id) => !posts[id]);
    if (missingPostIds.length > 0) {
      const postLookup = await this.getPosts(missingPostIds);
      if (postLookup) {
        this.setCachedPosts(postLookup);
        posts = this.getCachedPosts(data.order);
        this.Logger.log("Cache state:", PostCache.stats());
      } else {
        measurePerformance();
        if (requestExpired()) return;
        this.status = "error";
        container.html("<p class='error'>Failed to load recommended posts.</p>");
        return;
      }
      perf.mark("posts-fetched");
    } else {
      perf.mark("posts-fetched", "cached");
    }

    // 4. Request ID check.
    // Both caches are already warm; only rendering must not race a newer request.
    if (requestExpired()) {
      this.Logger.log("Aborted rendering due to newer request. Req ID:", requestID);
      measurePerformance();
      return;
    }

    // 5. Render thumbnails
    const renderedPosts: JQuery<HTMLElement>[] = [];
    for (const postId of data.order) {
      if (!data.results[postId]) continue;
      const post = posts[postId];
      if (!post || post.isDeleted) continue;

      // Replace placeholders in order to avoid layout shifts
      const rendered = ThumbnailEngine.render(post);
      if (!rendered) continue;
      container
        .find(".thumbnail.placeholder").first()
        .replaceWith(rendered);
      renderedPosts.push(rendered);
    }

    this.Logger.log(`Rendered ${renderedPosts.length} posts`, renderedPosts);
    this.Logger.log(" ⤷ Cache state:", PostCache.stats());
    perf.mark("rendered");

    // 7. Finalize
    this.status = "ready";
    container.find(".thumbnail.placeholder").remove();
    if (container.children().length === 0) {
      if (requestExpired()) {
        measurePerformance();
        return;
      }
      this.status = "error";
      container.html("<p class='info'>Nobody here but us chickens!</p>");
    }

    measurePerformance();
  }


  /* ============================== */
  /* ======= DOM Management ======= */
  /* ============================== */

  /** Resolves once the recommendations section scrolls into view */
  private waitUntilReady (): Promise<void> {
    return new Promise((resolve) => {
      const observer = new IntersectionObserver((entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          observer.disconnect();
          resolve();
        }
      }, { threshold: 0 });

      observer.observe(this.container[0]);
    });
  }


  /* ============================== */
  /* ======== API Queries ========= */
  /* ============================== */

  private async getData (action: RecommendationAction): Promise<RecommendationResponse | null> {
    const postId = CurrentPost.id;
    this.Logger.log(`Fetching data: "${postId}/${action}"`);

    try {
      const data = await HTTP.getJSON<RecommendationResponse>(
        `/posts/${postId}/similar/${action}.json`,
        { limit: Recommended.RESULT_COUNT },
      );
      this.Logger.log("Engine response:", data);
      return data;
    } catch (error) {
      console.error("Error fetching recommendations:", error);
      return null;
    }
  }

  private async getPosts (postIds: number[]): Promise<DeferredPostData[] | null> {
    this.Logger.log("Fetching posts:", postIds);

    try {
      const data = await HTTP.getJSON<DeferredPostData[]>("/posts.json", {
        v2: "true",
        mode: "thumbnail",
        tags: `id:${postIds.join(",")}`,
      });
      this.Logger.log("API response:", data);
      return data;
    } catch (error) {
      console.error("Error fetching posts:", error);
      return null;
    }
  }


  /* ============================== */
  /* ========== Caching =========== */
  /* ============================== */

  private getCachedPosts (postIds: number[]): Record<number, CachedPost> {
    const posts = PostCache.getManyByID(postIds);
    this.Logger.log(`Posts: ${Object.keys(posts).length}/${postIds.length} cached`);
    return posts;
  }

  private setCachedPosts (posts: DeferredPostData[]): void {
    for (const post of posts)
      PostCache.fromDeferredPosts(post.id, post);
  }
}
