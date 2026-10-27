import Blacklist from "@/core/blacklist";
import CurrentUser from "@/models/CurrentUser";
import PostCache, { CachedPost } from "@/models/PostCache";
import Settings from "@/utility/Settings";
import SVGIcon from "@/utility/SVGIcon";

/**
 * Client-side counterpart of PostThumbnailComponent.
 * Built with native DOM calls: a single comments page can render ~1000 avatars at once.
 */
export default class ThumbnailEngine {

  private static _counter = 0;
  public static get renderedCount () { return this._counter; }

  /**
   * Renders a thumbnail element for a given post.
   * Unavailable posts (no preview URL) and deleted posts the user may not see are rendered without a picture.
   *
   * Blacklist classes reflect the Blacklist state at render time, so posts loaded through
   * DeferredPostLoader come out right on the first paint. Anything else is corrected by the
   * Blacklist as soon as the thumbnail is registered.
   * @param {CachedPost} post Post data to render
   * @param {ThumbnailOptions} options Rendering options
   * @returns {JQuery<HTMLElement> | null} Rendered thumbnail element or null if the post cannot be rendered
   */
  public static render (post: CachedPost, options: ThumbnailOptions = {}): JQuery<HTMLElement> | null {
    if (!post) return null;

    const { showStatistics = true, showTypeBadges = true, inline = false, native = false, classes, jpegUrl, webpUrl } = options;

    // Resolve URL overrides into locals; the caller's post must not be mutated.
    let previewUrl = post.preview_url || "", previewWebp = post.preview_webp || "";
    if (!post.isUnavailable) {
      if (jpegUrl) previewUrl = previewUrl.replace(/\/data\/.*$/, jpegUrl);
      if (webpUrl) previewWebp = previewWebp ? previewWebp.replace(/\/data\/.*$/, webpUrl) : webpUrl;
    }

    const article = document.createElement("article");
    const classList = ["thumbnail", "rating-" + post.ratingLong];
    if (post.isDeleted || post.isUnavailable) classList.push("deleted");
    if (post.isPending) classList.push("pending");
    if (post.isFlagged) classList.push("flagged");
    if (Blacklist.hiddenPosts.has(post.id)) classList.push("blacklisted");
    if (Blacklist.matchedPosts.has(post.id)) classList.push("filter-matches");
    if (!showStatistics) classList.push("no-stats");
    if (!showTypeBadges) classList.push("no-type-badges");
    if (inline) classList.push("inline");
    if (native) classList.push("native");
    if (classes) classList.push(classes);
    article.className = classList.join(" ");

    for (const [key, value] of Object.entries(post.toAttributes()))
      if (value !== undefined) article.setAttribute(key, String(value));
    // Keep the dataset in sync with what is actually displayed
    if (previewUrl) article.setAttribute("data-preview-url", previewUrl);
    if (previewWebp) article.setAttribute("data-preview-webp", previewWebp);

    // Core
    const link = document.createElement("a");
    link.className = "thm-link";
    link.href = `/posts/${post.id}`;
    link.setAttribute("data-target", String(post.id)); // Used by Analytics
    link.setAttribute("data-file-ext", post.file_ext); // Used by the badge pseudoelement
    article.appendChild(link);

    const canSeeDeleted = CurrentUser.is.staff || CurrentUser.can.approvePosts;
    if (!post.isUnavailable && (!post.isDeleted || canSeeDeleted))
      link.appendChild(this.renderPicture(post, previewUrl, previewWebp));

    // CachedPost carries no parent/child data, so only the right ribbon can be rendered
    if (post.isFlagged || post.isPending)
      link.appendChild(this.renderRibbon(post));

    // Footer
    if (showStatistics) {
      const footer = document.createElement("div");
      footer.className = `thm-desc thm-rating-${post.rating}`;
      article.appendChild(footer);

      const stats = document.createElement("span");
      stats.className = "thm-desc-a";
      footer.appendChild(stats);
      stats.appendChild(this.renderScore(post.score));
      stats.appendChild(this.renderStat("thm-favorites", "favorites", post.fav_count));
      stats.appendChild(this.renderStat("thm-comments", "comments", post.comment_count));

      const rating = document.createElement("span");
      rating.className = "thm-desc-b thm-rating";
      rating.textContent = post.rating.toUpperCase();
      footer.appendChild(rating);
    }

    this._counter++;

    const $article = $(article);
    PostCache.register($article);
    return $article;
  }

  /**
   * Renders a placeholder thumbnail element
   * @returns {JQuery<HTMLElement>} Rendered placeholder thumbnail element
   */
  public static renderPlaceholder (): JQuery<HTMLElement> {
    const article = document.createElement("article");
    article.className = "thumbnail placeholder";
    return $(article);
  }

  /* ===== Render Thumbnail Parts ===== */

  private static renderPicture (post: CachedPost, previewUrl: string, previewWebp: string): HTMLPictureElement {
    const picture = document.createElement("picture");

    if (Settings.Posts.webp_enabled && previewWebp) {
      const source = document.createElement("source");
      source.srcset = previewWebp;
      source.type = "image/webp";
      picture.appendChild(source);
    }

    const img = document.createElement("img");
    img.src = previewUrl;
    img.alt = `post #${post.id}`;
    img.setAttribute("loading", "lazy");
    picture.appendChild(img);

    return picture;
  }

  // Mirrors PostThumbnailComponent#ribbon_tooltip(:right)
  private static renderRibbon (post: CachedPost): HTMLDivElement {
    const content = [];
    if (post.isFlagged) content.push("flagged for deletion");
    if (post.isPending) content.push("pending for approval");
    const title = content.join(" and ");

    const ribbon = document.createElement("div");
    ribbon.className = "ribbon right";
    ribbon.title = title.charAt(0).toUpperCase() + title.slice(1) + ".";
    ribbon.setAttribute("aria-hidden", "true");
    return ribbon;
  }

  private static renderScore (score: number): HTMLSpanElement {
    const icon = score > 0 ? "arrow_up_dash" : (score < 0 ? "arrow_down_dash" : "score");
    const polarity = score > 0 ? "positive" : (score < 0 ? "negative" : "neutral");
    return this.renderStat(`thm-score thm-score-${polarity}`, icon, score);
  }

  private static renderStat (className: string, icon: string, value: number): HTMLSpanElement {
    const span = document.createElement("span");
    span.className = "thm-desc-m " + className;
    const svg = SVGIcon.render(icon);
    if (svg) span.appendChild(svg);
    span.appendChild(document.createTextNode(this.shortenValue(value)));
    return span;
  }

  // Mirrors PostThumbnailComponent#shortened_value
  private static shortenValue (value: number): string {
    if (!value) return "0";
    value = Math.abs(value);
    if (value >= 1000) return (value / 1000).toFixed(1) + "k";
    return String(value);
  }
}

type ThumbnailOptions = {
  showStatistics?: boolean;
  showTypeBadges?: boolean;
  inline?: boolean;
  native?: boolean;
  classes?: string;

  jpegUrl?: string;
  webpUrl?: string;
};
