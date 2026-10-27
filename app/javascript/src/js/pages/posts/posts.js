import Hotkeys from "@/core/hotkeys";
import CurrentUser from "@/models/CurrentUser";
import PostModel from "@/models/Post";
import PostApproval from "@/models/PostApproval";
import PostFlag from "@/models/PostFlag";
import PostVote from "@/models/PostVote";
import { ApiError } from "@/utility/ApiRequest";
import Page from "@/utility/Page";
import ToastManager from "@/utility/Toast";

// Facade over the API models for the index-style bulk actions. Owns the
// pending-update toast and thumbnail DOM updates; the HTTP calls live in
// models/, and the posts#show page glue lives in pages/posts/show/.
let Post = {};

// Legacy callers pass flat Rails keys ({"post[rating]": "q"}); the model takes the nested shape.
export function unwrapPostParams (params) {
  const unwrapped = {};
  for (const [key, value] of Object.entries(params)) {
    const match = key.match(/^post\[(.+)\]$/);
    unwrapped[match ? match[1] : key] = value;
  }
  return unwrapped;
}

Post.pending_update_toast = null;
Post.pending_update_count = 0;

Post.initialize_all = function () {
  // `random` works off the search box, which index, show and favorites all render
  if ((Page.Controller == "posts" && ["index", "show"].includes(Page.Action)) || Page.Controller == "favorites")
    this.initialize_shortcuts();

  this.initialize_collapse();
};

Post.initialize_collapse = function () {
  $(".tag-list-header").on("click", function (e) {
    const category = $(e.target).data("category");
    $(`.${category}-tag-list`).toggle();
    $(e.target).toggleClass("hidden-category");
    e.preventDefault();
  });
};

Post.initialize_shortcuts = function () {
  Hotkeys.register("random", () => {
    const query = $("#tags").val() + "";
    if (!query) {
      location.href = "/posts/random";
      return;
    }

    const encodedTags = [];
    for (const one of query.split(" ").filter(n => n))
      encodedTags.push(encodeURIComponent(one));
    location.href = "/posts/random?tags=" + encodedTags.join("+");
  });
};

Post.notice_update = function (x) {
  if (!Post.pending_update_toast) {
    Post.pending_update_toast = ToastManager.create("Updating posts...", { timeout: 0 });
  }
  ToastManager.dismiss("Posts updated");

  if (x === "inc") {
    Post.pending_update_count += 1;
    Post.pending_update_toast.message = "Updating posts (" + Post.pending_update_count + " pending)...";
  } else {
    Post.pending_update_count -= 1;

    if (Post.pending_update_count < 1) {
      Post.pending_update_toast.message = "Posts updated";
      Post.pending_update_toast.timeout = 3;
      Post.pending_update_toast = null;
    } else {
      Post.pending_update_toast.message = "Updating posts (" + Post.pending_update_count + " pending)...";
    }
  }
};

Post.update_data = function (data) {
  var $post = Post.getMatchingThumbnails(data.id);
  $post.attr("data-tags", data.tag_string);
  $post.data("rating", data.rating);

  $post.toggleClass("has-parent", data.parent_id);
  $post.toggleClass("has-children", data.has_visible_children);
  $post.toggleClass("flagged", data.is_flagged);
  $post.toggleClass("pending", data.is_pending);
};

Post.tag = function (post_id, tags) {
  const tag_string = (Array.isArray(tags) ? tags.join(" ") : String(tags));
  return Post.update(post_id, { "post[old_tag_string]": "", "post[tag_string]": tag_string });
};

Post.tagScript = function (post_id, tags, reason = "") {
  const tag_string = (Array.isArray(tags) ? tags.join(" ") : String(tags));
  return Post.update(post_id, { "post[tag_string_diff]": tag_string, "post[edit_reason]": reason });
};

Post.getMatchingThumbnails = function (post_id) {
  return $(`article.thumbnail[data-id="${post_id}"]`);
};

Post.update = function (post_id, params) {
  Post.notice_update("inc");
  return PostModel.update(post_id, unwrapPostParams(params))
    // TODO: update_data reads data.id, but the endpoint answers { post: {...} }; silent no-op today.
    .then((data) => Post.update_data(data))
    .catch(() => { /* Reported through danbooru:error */ })
    .finally(() => Post.notice_update("dec"));
};

Post.delete_with_reason = function (post_id, reason, options = {}) {
  const { reload_after_delete = false, from_flag = false, move_favorites = false,
    dmail = null, dmail_title = null } = options;

  Post.notice_update("inc");
  return PostModel.delete(post_id, { reason, from_flag, move_favorites, dmail, dmail_title })
    .then(() => {
      ToastManager.notice("Deleted post.");
      if (reload_after_delete) {
        location.reload();
      } else {
        Post.getMatchingThumbnails(post_id).attr("data-flags", "deleted");
      }
    })
    .catch((error) => {
      // Already deleted elsewhere: the page is stale
      if (error instanceof ApiError && error.status === 409) location.reload();
    })
    .finally(() => Post.notice_update("dec"));
};

Post.undelete = function (post_id, callback) {
  Post.notice_update("inc");
  return PostModel.undelete(post_id)
    .then(() => {
      Post.getMatchingThumbnails(post_id).attr("data-flags", "active");
      ToastManager.notice("Undeleted post.");
      if (callback) callback();
    })
    .catch(() => { /* Reported through danbooru:error */ })
    .finally(() => Post.notice_update("dec"));
};

Post.unflag = function (post_id, approval, reload = true, callback = null) {
  Post.notice_update("inc");
  return PostFlag.destroy(post_id, approval || "none")
    .then(() => {
      Post.getMatchingThumbnails(post_id).removeClass("flagged");
      ToastManager.notice("Unflagged post");
      if (callback) callback();
      if (reload) location.reload();
    })
    .catch(() => { /* Reported through danbooru:error */ })
    .finally(() => Post.notice_update("dec"));
};

Post.flag = function (post_id, reason_name, parent_id = null, note = null, reload = true, callback = null) {
  Post.notice_update("inc");
  return PostFlag.create(parseInt(post_id), { reason_name, parent_id, note })
    .then(() => {
      ToastManager.notice("Flagged post");
      if (callback) callback();
      if (reload) location.reload();
    })
    .catch(() => { /* Reported through danbooru:error */ })
    .finally(() => Post.notice_update("dec"));
};

Post.move_flag_to_parent = function (post_id, parent_id, reason_name, note) {
  Post.unflag(post_id, false, false, function () {
    Post.flag(parent_id, reason_name, post_id, note, false, function () {
      location.href = `/staff/post/posts/${parent_id}/confirm_delete`;
    });
  });
};

Post.unapprove = function (post_id) {
  Post.notice_update("inc");
  return PostApproval.destroy(post_id)
    .then(() => {
      ToastManager.notice("Unapproved post.");
      location.reload();
    })
    .catch(() => { /* Reported through danbooru:error */ })
    .finally(() => Post.notice_update("dec"));
};

Post.destroy = function (post_id, reason) {
  return PostModel.expunge(post_id, reason)
    .then(() => {
      location.href = `/staff/destroyed_posts/${post_id}`;
    })
    .catch(() => { /* Reported through danbooru:error */ });
};

Post.regenerate_image_samples = function (post_id) {
  return PostModel.regenerateImageSamples(post_id)
    .then(() => {
      if ($("#image-container").data("size") >= 10 * 1024 * 1024) {
        ToastManager.notice("Large file: Image samples will be regenerated soon.");
      } else {
        ToastManager.notice("Image samples regenerated successfully.");
      }
    })
    .catch(() => { /* Reported through danbooru:error */ });
};

Post.regenerate_video_samples = function (post_id) {
  return PostModel.regenerateVideoSamples(post_id)
    .then(() => {
      ToastManager.notice("Video samples will be regenerated in a few minutes.");
    })
    .catch(() => { /* Reported through danbooru:error */ });
};

Post.approve = function (post_id, callback) {
  Post.notice_update("inc");
  return PostApproval.create(post_id)
    .then(() => {
      const $thumbnails = Post.getMatchingThumbnails(post_id);
      if ($thumbnails.length) {
        $thumbnails.data("flags", $thumbnails.data("flags").replace(/pending/, ""));
        $thumbnails.removeClass("pending");
        ToastManager.notice("Approved post #" + post_id);
      }
      if (callback) callback();
    })
    .catch(() => { /* Reported through danbooru:error */ })
    .finally(() => Post.notice_update("dec"));
};

Post.disapprove = function (post_id, reason, message) {
  Post.notice_update("inc");
  return PostApproval.disapprove(post_id, reason, message)
    .then(() => {
      if ($("#c-posts #a-show").length) location.reload();
    })
    .catch(() => { /* Reported through danbooru:error */ })
    .finally(() => Post.notice_update("dec"));
};

Post.vote = function (id, score, prevent_unvote) {
  console.log("Post.vote is deprecated and will be removed at a later date. User PostVote.vote instead.");
  PostVote.vote(id, score, prevent_unvote);
};

Post.set_as_avatar = function (id) {
  return CurrentUser.setAvatar(id)
    .then(() => {
      ToastManager.notice("Post set as avatar. You can crop it further <a href='/maintenance/user/avatar/edit'>here</a>.");
    })
    .catch(() => { /* Reported through danbooru:error */ });
};

$(() => {
  Post.initialize_all();
});

export default Post;
