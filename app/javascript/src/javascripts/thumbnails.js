import Blacklist from "./blacklists";
import LStorage from "./utility/storage";

const Thumbnails = {};

Thumbnails.initialize = function () {
  const postsData = window.___deferred_posts || {};
  const posts = $(".post-thumb.placeholder, .thumb-placeholder-link");
  const DAB = LStorage.get("dab") === "1";

  for (const post of posts) {
    const $post = $(post);

    // Placeholder is valid
    const postID = $post.data("id");
    if (!postID) {
      clearPlaceholder($post);
      return;
    }

    // Data exists for this post
    const postData = postsData[postID];
    if (!postData) {
      clearPlaceholder($post);
      return;
    }

    // Building the element
    const thumbnail = $("<div>")
      .addClass("post-thumbnail blacklistable")
      .toggleClass("dtext", $post.hasClass("thumb-placeholder-link"));
    for (const key in postData)
      thumbnail.attr("data-" + key.replace(/_/g, "-"), postData[key]);

    const link = $("<a>")
      .attr("href", `/posts/${postData.id}`)
      .appendTo(thumbnail);

    $("<img>")
      .attr({
        src: postData["preview_url"] || "/images/deleted-preview.png",
        height: postData["preview_url"] ? postData["preview_height"] : 150,
        width: postData["preview_url"] ? postData["preview_width"] : 150,
        title: `Rating: ${postData.rating}\r\nID: ${postData.id}\r\nStatus: ${postData.flags}\r\nDate: ${postData["created_at"]}\r\n\r\n${postData.tags}`,
        alt: postData.tags,
        class: "post-thumbnail-img",
      })
      .appendTo(link);

    // Disgusting implementation of the blacklist
    if (!DAB) {
      let blacklist_hit_count = 0;
      for (const entry of Blacklist.entries) {
        if (!Blacklist.postMatchObject(postData, entry))
          continue;
        entry.hits += 1;
        blacklist_hit_count += 1;
      }

      if (blacklist_hit_count > 0)
        thumbnail.addClass("blacklisted");
    }

    $post.replaceWith(thumbnail);
  }

  function clearPlaceholder (post) {
    if (post.hasClass("thumb-placeholder-link"))
      post.removeClass("thumb-placeholder-link");
    else post.empty();
  }
};

$(() => {
  Thumbnails.initialize();
  $(window).on("e621:add_deferred_posts", (_, posts) => {
    window.___deferred_posts = window.___deferred_posts || {};
    window.___deferred_posts = $.extend(window.___deferred_posts, posts);
    Thumbnails.initialize();
  });
  $(document).on("thumbnails:apply", Thumbnails.initialize);
});

export default Thumbnails;
