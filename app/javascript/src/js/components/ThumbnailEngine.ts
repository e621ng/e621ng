import E621Type from "@/interfaces/E621";
import PostCache, { CachedPost } from "@/models/PostCache";
import User from "@/models/User";
import Settings from "@/utility/Settings";
import SVGIcon from "@/utility/SVGIcon";

declare const E621: E621Type;

export default class ThumbnailEngine {

  private static _counter = 0;
  public static get renderedCount () { return this._counter; }

  /**
   * Renders a thumbnail element for a given post.
   * If the post is null, returns null.
   * If a post is missing preview data, it will render a placeholder thumbnail with a "deleted" image.
   * @param {CachedPost} post Post data to render
   * @returns {JQuery<HTMLElement> | null} Rendered thumbnail element or null if the post cannot be rendered
   */
  public static render (post: CachedPost, options: ThumbnailOptions = {}): JQuery<HTMLElement> | null {
    if (!post) return null;

    const { showStatistics = true, showTypeBadges = true, inline = false, native = false, classes, jpegUrl, webpUrl } = options;

    const article = $("<article>")
      .addClass("thumbnail rating-" + (post.ratingLong))
      .attr(post.toAttributes());

    if (post.isDeleted) article.addClass("deleted");

    // Apply customization and blacklist classes
    if (E621.Blacklist.hiddenPosts.has(post.id)) article.addClass("blacklisted");
    if (E621.Blacklist.matchedPosts.has(post.id)) article.addClass("filter-matches");

    if (!showStatistics) article.addClass("no-stats");
    if (!showTypeBadges) article.addClass("no-type-badges");
    if (inline) article.addClass("inline");
    if (native) article.addClass("native");
    if (classes) article.addClass(classes);

    // Substitute URLs if necessary
    if (jpegUrl) {
      if (post.preview_url) post.preview_url = post.preview_url.replace(/\/data\/.*$/, jpegUrl);
      else post.preview_url = jpegUrl;
    }
    if (webpUrl) {
      if (post.preview_webp) post.preview_webp = post.preview_webp.replace(/\/data\/.*$/, webpUrl);
      else post.preview_webp = webpUrl;
    }

    // Core
    const link = $("<a>")
      .addClass("thm-link")
      .attr({
        "href": `/posts/${post.id}`,
        "data-target": post.id, // Used by Analytics
      })
      .appendTo(article);
    if (!post.isDeleted || User.is.janitor)
      link.append(this.renderPicture(post));

    // Footer
    if (showStatistics) {
      const footer = $("<div>")
        .addClass(`thm-desc thm-rating-${post.rating}`)
        .appendTo(article);

      $("<span class='thm-desc-a'>")
        .appendTo(footer)
        .append(this.renderScore(post.score))
        .append(this.renderFavorites(post.fav_count))
        .append(this.renderComments(post.comment_count));

      this.renderRating(post.rating)
        .appendTo(footer);
    }

    this._counter++;

    PostCache.register(article);
    return article;
  }

  /**
   * Renders a placeholder thumbnail element
   * @returns {JQuery<HTMLElement>} Rendered placeholder thumbnail element
   */
  public static renderPlaceholder (): JQuery<HTMLElement> {
    return $("<article>")
      .addClass("thumbnail placeholder");
  }

  /* ===== Render Thumbnail Parts ===== */

  private static renderPicture (post: CachedPost) {
    const picture = $("<picture>");
    const preview_url = post.preview_url || "/images/deleted-preview.png";

    if (Settings.Posts.webp_enabled && post.preview_webp)
      $("<source>")
        .attr({ "srcset": post.preview_webp, "type": "image/webp" })
        .appendTo(picture);

    $("<img>")
      .attr({
        "src": preview_url,
        "alt": `post #${post.id}`,
        "loading": "lazy",
      })
      .appendTo(picture);

    return picture;
  }

  private static renderScore (score: number) {
    const scoreIcon = score > 0 ? "arrow_up_dash" : (score < 0 ? "arrow_down_dash" : "score");

    return $("<span>")
      .addClass("thm-desc-m thm-score")
      .addClass(score > 0 ? "thm-score-positive" : score < 0 ? "thm-score-negative" : "thm-score-neutral")
      .append(SVGIcon.render(scoreIcon))
      .append(String(Math.abs(score)));
  }

  private static renderFavorites (favCount: number) {
    return $("<span>")
      .addClass("thm-desc-m thm-favorites")
      .append(SVGIcon.render("favorites"))
      .append(String(favCount));
  }

  private static renderComments (commentCount: number) {
    return $("<span>")
      .addClass("thm-desc-m thm-comments")
      .append(SVGIcon.render("comments"))
      .append(String(commentCount));
  }

  private static renderRating (rating: string) {
    return $("<span>")
      .addClass("thm-desc-b thm-rating")
      .text((rating || "?").toUpperCase());
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

