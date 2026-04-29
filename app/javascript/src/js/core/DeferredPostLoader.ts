import { RawPostData } from "@/models/PostCache";

// Cursed way to pass post data from Rails to the frontend.

import ThumbnailEngine from "@/components/ThumbnailEngine";
import E621Type from "@/interfaces/E621";
import PostCache from "@/models/PostCache";

declare const E621: E621Type;

// Same format as Post.thumbnail_attributes
declare global {
  interface Window {
    ___deferred_posts: any;
  }
}

export default class DeferredPostLoader {

  public static loadPostData (postsData: DeferredPostsData = window.___deferred_posts || {}) {
    if (typeof postsData !== "object") return;
    if (Object.keys(postsData).length === 0) return;

    console.log("Loading deferred posts:", postsData);

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

    E621.Logger.log("Deferred posts", "\n ⤷ Loaded: " + processed.length, "\n ⤷ In cache: " + PostCache.stats().cachedPosts);

    window.___deferred_posts = {};
  }

  public static renderNavbarAvatar () {
    const avatar = $(".simple-avatar.placeholder").first();
    if (!avatar.length) return;
    avatar.removeClass("placeholder"); // don't reload no matter what

    const postID = avatar.data("id");
    if (!postID) return;
    const post = PostCache.get(postID);
    if (!post || !post.preview_url) return;

    $("<img>")
      .attr("src", post.preview_url)
      .appendTo(avatar.find("span.avatar-image"));
  }

  public static renderDTextThumbnails () {
    for (const placeholder of $(".thumb-placeholder-link")) {
      const $placeholder = $(placeholder);
      const postID = $placeholder.data("id");
      if (!postID) continue;
      const post = PostCache.get(postID);
      if (!post) continue;

      const thumbnail = ThumbnailEngine.render(post, { showStatistics: false, inline: true, native: true });
      if (!thumbnail) continue;
      $placeholder.replaceWith(thumbnail);
    }

    // Any placeholders left cannot be rendered
    $(".thumb-placeholder-link").removeClass("thumb-placeholder-link");
  }

  public static renderUserAvatars () {
    for (const placeholder of $(".post-thumb.placeholder")) {
      const $placeholder = $(placeholder);
      const postID = $placeholder.data("id");
      if (!postID) continue;
      const post = PostCache.get(postID);
      if (!post) continue;

      const thumbnail = ThumbnailEngine.render(post, { showStatistics: false, showTypeBadges: false, inline: true, native: true });
      if (!thumbnail) continue;
      $placeholder.replaceWith(thumbnail);
    }

    // Any placeholders left cannot be rendered
    $(".post-thumb.placeholder").removeClass("placeholder");
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

type DeferredPostsData = { [id: number]: RawPostData };
