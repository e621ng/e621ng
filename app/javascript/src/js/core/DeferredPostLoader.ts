import ThumbnailEngine from "@/components/ThumbnailEngine";
import E621Type from "@/interfaces/E621";
import PostCache, { DeferredPostData } from "@/models/PostCache";
import Logger from "@/utility/Logger";

// Cursed way to pass post data from Rails to the frontend.

declare const E621: E621Type;

// Same format as Post.thumbnail_attributes
declare global {
  interface Window {
    ___deferred_posts: any;
  }
}

export default class DeferredPostLoader {

  private static Logger = new Logger("Deferred");

  public static loadPostData (postsData: Record<number, DeferredPostData> = window.___deferred_posts || {}) {
    if (typeof postsData !== "object") return;
    if (Object.keys(postsData).length === 0) return;

    const processed = [];
    for (const [id, data] of Object.entries(postsData)) {
      const postID = parseInt(id, 10);
      if (!postID || !data) continue;
      const post = PostCache.fromDeferredPosts(postID, data, true);
      if (post) processed.push(post);
    }

    // At this point, no thumbnails are rendered.
    // However, this lets us populate the Blacklist and render thumbnails with the correct
    // visibility on the first try, instead of rendering them and then updating their visibility.
    E621.Blacklist.load_deferred_posts(processed);
    E621.Blacklist.update_visibility();
    E621.Blacklist.update_styles();

    this.Logger.log("Loaded post data", "\n ⤷ Processed: " + processed.length + " / " + Object.keys(postsData).length, "\n ⤷ In cache: " + PostCache.stats().cachedPosts);

    window.___deferred_posts = {};
  }

  public static renderNavbarAvatar () {
    const avatars = $(".savm-profile-icon.placeholder");
    if (!avatars.length) return;
    avatars.removeClass("placeholder");

    // Determine avatar data from the first placeholder
    const avatar = $(avatars[0]);
    const postID = avatar.data("id");
    if (!postID) return;
    const post = PostCache.get(postID);
    if (!post || !post.preview_url) return;

    let path = post.preview_url;
    if (!post.isDeleted && avatar.data("has-cropped-avatar")) {
      const userID = avatar.data("user-id") || "0",
        userHash = avatar.data("user-hash") || "0";
      if (userID) path = post.preview_url.replace(/\/data\/.*$/, `/data/avatars/${userID}.jpg?t=${userHash}`);
    }

    // Avatars are rendered without accounting for blacklist.
    // If someone blacklists their own avatar, it's their problem.

    for (const placeholder of avatars) {
      const $placeholder = $(placeholder);
      $("<img>")
        .attr({
          "src": path,
          "alt": "User avatar",
        })
        .appendTo($placeholder);
    }
  }

  public static renderDTextThumbnails () {
    let counter = 0;
    for (const placeholder of $(".thumb-placeholder-link")) {
      const $placeholder = $(placeholder);
      const postID = $placeholder.data("id");
      if (!postID) continue;
      const post = PostCache.get(postID);
      if (!post) continue;

      const thumbnail = ThumbnailEngine.render(post, { showStatistics: false, inline: true, native: true });
      if (!thumbnail) continue;
      $placeholder.replaceWith(thumbnail);
      counter++;
    }

    // Any placeholders left cannot be rendered
    const unrendered = $(".thumb-placeholder-link")
      .removeClass("thumb-placeholder-link");

    this.Logger.log("Rendered DText thumbnails", "\n ⤷ Count: " + counter, "\n ⤷ Unrendered: " + unrendered.length);
  }

  public static renderUserAvatars () {
    let counter = 0;
    for (const placeholder of $("article.thumbnail.avatar.placeholder")) {
      const $placeholder = $(placeholder);
      if ($placeholder.hasClass("no-render")) continue;

      const postID = $placeholder.data("id");
      if (!postID) continue;
      const post = PostCache.get(postID);
      if (!post) continue;

      let jpgUrl: string, webpUrl: string;
      if (!post.isDeleted && $placeholder.data("has-cropped-avatar")) {
        const userID = $placeholder.data("user-id") || "0",
          userHash = $placeholder.data("user-hash") || "0";
        jpgUrl = `/data/avatars/${userID}.jpg?t=${userHash}`;
        webpUrl = `/data/avatars/${userID}.webp?t=${userHash}`;
      }

      const thumbnail = ThumbnailEngine.render(post, {
        showStatistics: false,
        showTypeBadges: false,
        inline: true,
        jpegUrl: jpgUrl,
        webpUrl: webpUrl,
        classes: "avatar",
      });
      if (!thumbnail) continue;

      if ($placeholder.data("initial"))
        thumbnail.find("a.thm-link").attr("data-initial", $placeholder.data("initial"));

      $placeholder.replaceWith(thumbnail);
      counter++;
    }

    this.Logger.log("Rendered avatars", "\n ⤷ Count: " + counter);
  }
}

$(() => {
  DeferredPostLoader.loadPostData();
  DeferredPostLoader.renderNavbarAvatar();
  DeferredPostLoader.renderDTextThumbnails();
  DeferredPostLoader.renderUserAvatars();

  // Backwards compatibility - prefer to call .loadPostData() directly.
  // Does not do any pruning, so the blacklist will gradually get more and more inaccurate
  // as posts are removed from the DOM. This event is only intended to be triggered on one-off
  // occasions (ex. reloading a blip after marking it), so it shouldn't cause too much of an issue.
  $(window).on("e621:add_deferred_posts", (_, posts) => {
    DeferredPostLoader.loadPostData(posts);
    DeferredPostLoader.renderDTextThumbnails();
    DeferredPostLoader.renderUserAvatars();
  });
});
