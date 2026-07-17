import Hotkeys from "@/core/hotkeys";
import PostVote from "@/models/PostVote";
import Page from "@/utility/Page";
import LStorage from "@/utility/storage/Local";
import SVGIcon from "@/utility/SVGIcon";
import TaskQueue from "@/utility/TaskQueue";
import ToastManager from "@/utility/Toast";
import CurrentUser from "@/models/CurrentUser";

let Post = {};

Post.pending_update_toast = null;
Post.pending_update_count = 0;

Post.initialize_all = function () {

  if ((Page.Controller == "posts" && ["index", "show"].includes(Page.Action)) || Page.Controller == "favorites")
    this.initialize_shortcuts();

  if ($("#c-posts").length) {
    this.initialize_shortcuts();
  }

  if ($("#c-posts").length && $("#a-show").length) {
    this.initialize_links();
    this.initialize_post_relationship_previews();
    this.initialize_post_sections();
    this.initialize_moderation();
  }

  this.initialize_collapse();

  $(document).on("danbooru:open-post-edit-tab", () => {
    Hotkeys.enabled = false;
    // Not going to happen until the Vue app is mounted.
    // See tag_editor.vue for the workaround.
    $("#post_tag_string").trigger("focus");
    window.scrollTo({ top: $("#edit").offset().top - 80, behavior: "smooth" });
  });
  $(document).on("danbooru:close-post-edit-tab", () => Hotkeys.enabled = true);
  $("#tag-string-editor").on("e6ng:vue-mounted", () => {
    Post.update_tag_count();
  });

  var $fields_multiple = $("[data-autocomplete=\"tag-edit\"]");
  $fields_multiple.on("keypress.danbooru", Post.update_tag_count);
  $fields_multiple.on("click", Post.update_tag_count);
};

Post.initialize_moderation = function () {
  $("#unapprove-post-link").on("click", e => {
    Post.unapprove($(e.target).data("pid"));
    e.preventDefault();
  });
  $(".unflag-post-link").on("click", e => {
    const $e = $(e.target);
    Post.unflag($e.data("pid"), $e.data("type"));
    e.preventDefault();
  });
  $(".move-flag-to-parent-link").on("click", e => {
    e.preventDefault();
    const $e = $(e.target);
    const post_id = $e.data("pid");
    const parent_id = $e.data("parent-id");
    const reason_name = $e.data("reason-name");
    const note = $e.data("note");

    if (confirm("Move flag to parent?"))
      Post.move_flag_to_parent(post_id, parent_id, reason_name, note);
  });
};

Post.initialize_collapse = function () {
  $(".tag-list-header").on("click", function (e) {
    const category = $(e.target).data("category");
    $(`.${category}-tag-list`).toggle();
    $(e.target).toggleClass("hidden-category");
    e.preventDefault();
  });
};

Post.has_next_target = function () {
  return $(".paginator a[rel~=next]").length || $(".search-seq-nav a[rel~=next]").length || $(".pool-nav li.pool-selected-true a[rel~=next], .set-nav a.active[rel~=next]").length;
};

Post.has_prev_target = function () {
  return $(".paginator a[rel~=prev]").length || $(".search-seq-nav a[rel~=prev]").length || $(".pool-nav li.pool-selected-true a[rel~=prev], .set-nav a.active[rel~=prev]").length;
};

Post.nav_prev = function () {
  var href;

  if ($(".search-seq-nav").length) {
    href = $(".search-seq-nav a[rel~=prev]").attr("href");
    if (href) {
      location.href = href;
    }
  } else if ($(".paginator a[rel~=prev]").length) {
    location.href = $("a[rel~=prev]").attr("href");
  } else {
    href = $(".pool-nav li.pool-selected-true a[rel~=prev], .set-nav li.set-selected-true a[rel~=prev]").attr("href");
    if (href) {
      location.href = href;
    }
  }
};

Post.nav_next = function () {
  var href;

  if ($(".search-seq-nav").length) {
    href = $(".search-seq-nav a[rel~=next]").attr("href");
    location.href = href;
  } else if ($(".paginator a[rel~=next]").length) {
    location.href = $(".paginator a[rel~=next]").attr("href");
  } else {
    href = $(".pool-nav li.pool-selected-true a[rel~=next], .set-nav li.set-selected-true a[rel~=next]").attr("href");
    if (href) {
      location.href = href;
    }
  }
};

Post.initialize_shortcuts = function () {
  if (Page.Action == "show") {
    Hotkeys.register("prev", Post.nav_prev);
    Hotkeys.register("next", Post.nav_next);
  }

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

Post.initialize_links = function () {
  $(".undelete-post-link").on("click", e => {
    e.preventDefault();
    if (!confirm("Are you sure you want to undelete this post?"))
      return;
    Post.undelete($(e.target).data("pid"), () => {
      location.reload();
    });
  });
  $(".approve-post-link").on("click", e => {
    e.preventDefault();
    Post.approve($(e.target).data("pid"), () => {
      location.reload();
    });
  });
  $(".approve-post-and-navigate-link").on("click", e => {
    e.preventDefault();
    const $target = $(e.target);
    Post.approve($target.data("pid"), () => {
      location.href = $target.data("location");
    });
  });
  $("#destroy-post-link").on("click", e => {
    e.preventDefault();
    const reason = prompt("This will permanently delete this post (meaning the file will be deleted). What is the reason for destroying the post?");
    if (reason === null) return;
    Post.destroy($(e.target).data("pid"), reason);
  });
  $("#regenerate-image-samples-link").on("click", e => {
    e.preventDefault();
    Post.regenerate_image_samples($(e.target).data("pid"));
  });
  $("#regenerate-video-samples-link").on("click", e => {
    e.preventDefault();
    Post.regenerate_video_samples($(e.target).data("pid"));
  });
  $(".disapprove-post-link").on("click", e => {
    e.preventDefault();
    const target = $(e.target);
    Post.disapprove(target.data("pid"), target.data("reason"));
  });
  $("#set-as-avatar-link").on("click.danbooru", function (e) {
    e.preventDefault();
    if (!confirm("Set post as avatar?"))
      return;
    Post.set_as_avatar($(e.target).data("post-id"));
  });
  $("#copy-notes").on("click.danbooru", function (e) {
    var current_post_id = $("meta[name=post-id]").attr("content");
    var other_post_id = parseInt(prompt("Enter the ID of the post to copy all notes to:"), 10);

    if (other_post_id !== null) {
      $.ajax("/posts/" + current_post_id + "/copy_notes", {
        type: "PUT",
        data: {
          other_post_id: other_post_id,
        },
        success: function () {
          E621.Toast.notice("Successfully copied notes to <a href='" + other_post_id + "'>post #" + other_post_id + "</a>");
        },
        error: function (data) {
          if (data.status === 404) {
            E621.Toast.alert("Error: Invalid destination post");
          } else if (data.responseJSON && data.responseJSON.reason) {
            E621.Toast.alert("Error: " + data.responseJSON.reason);
          } else {
            E621.Toast.alert("There was an error copying notes to <a href='" + other_post_id + "'>post #" + other_post_id + "</a>");
          }
        },
      });
    }

    e.preventDefault();
  });
};

Post.initialize_post_relationship_previews = function () {
  var current_post_id = $("meta[name=post-id]").attr("content");
  $("[id=post_" + current_post_id + "]").addClass("current-post");

  const toggle = function () {
    Post.toggle_relationship_preview($("#has-children-relationship-preview"), $("#has-children-relationship-preview-link"));
    Post.toggle_relationship_preview($("#has-parent-relationship-preview"), $("#has-parent-relationship-preview-link"));
  };

  const flip_saved = function () {
    LStorage.Posts.ShowPostChildren = !LStorage.Posts.ShowPostChildren;
  };

  if (LStorage.Posts.ShowPostChildren)
    toggle();

  $("#has-children-relationship-preview-link").on("click.danbooru", function (e) {
    toggle();
    flip_saved();
    e.preventDefault();
  });
  $("#has-parent-relationship-preview-link").on("click.danbooru", function (e) {
    toggle();
    flip_saved();
    e.preventDefault();
  });
};

Post.toggle_relationship_preview = function (preview, preview_link) {
  preview.toggle();
  if (preview.is(":visible")) {
    preview_link.text("« hide");
  } else {
    preview_link.text("show »");
  }
};

Post._isEditing = false;
Post.initialize_post_sections = function () {
  if (E621.CurrentUser.is.anonymous) return;

  $("#side-edit-link, #post-edit-link, #menu-post-edit-link, #post-edit-close").on("click.danbooru", (event) => {
    event.preventDefault(); // Only one of these is a link
    Post._isEditing = !Post._isEditing;

    if (Post._isEditing) {
      Post.update_tag_count();
      $("#edit").show();
      $(document).trigger("danbooru:open-post-edit-tab");
    } else {
      $(document).trigger("danbooru:close-post-edit-tab");
      $("#edit").hide();
    }
  });

  const isUrlValid = (url, ignoreUrls = []) => {
    url = url.trim();
    if (url.length <= 0) {
      return true;
    }
    // So existing invalid source links are skipped
    if (ignoreUrls.includes(url)) {
      return true;
    }
    // Allow dead source links prefixed with `-`
    if (url[0] === "-") {
      url = url.substring(1);
    }
    try {
      const parsed = new URL(url);
      return parsed.protocol === "http:" || parsed.protocol === "https:";
    } catch {
      // Exception occurs if the URL constructor fails to parse the string, which means it's not a valid URL
      return false;
    }
  };

  const allUrlsValid = (urls, ignoreUrls = []) => {
    return urls.every(url => isUrlValid(url, ignoreUrls));
  };

  const splitUrls = urls => urls?.split(/\r?\n/) || [];

  const oldSources = splitUrls($("input[name='post[old_source]']").val());
  const invalidOldSources = oldSources.filter(url => !isUrlValid(url));

  const updateForUrlChange = () => {
    const newSources = splitUrls($("#post_source").val());
    const newSourcesValid = allUrlsValid(newSources, oldSources);
    $("#post-edit-invalid-url-error")[0].style.display = newSourcesValid ? "none" : "";
    $("#edit #form input[type=\"submit\"]")[0].disabled = !newSourcesValid;
    const hasOldInvalidSource = newSources.some(url => invalidOldSources.includes(url));
    $("#post-edit-invalid-url-warning")[0].style.display = !hasOldInvalidSource ? "none" : "";
  };

  $(document).on("danbooru:open-post-edit-tab", updateForUrlChange);
  $("#post_source").on("change.danbooru", updateForUrlChange);
};

Post.notice_update = function (x) {
  if (!Post.pending_update_toast) {
    Post.pending_update_toast = E621.Toast.create("Updating posts...", { timeout: 0 });
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
  Post.update(post_id, { "post[old_tag_string]": "", "post[tag_string]": tag_string });
};

Post.tagScript = function (post_id, tags) {
  const tag_string = (Array.isArray(tags) ? tags.join(" ") : String(tags));
  Post.update(post_id, { "post[tag_string_diff]": tag_string });
};

Post.getMatchingThumbnails = function (post_id) {
  return $(`article.thumbnail[data-id="${post_id}"]`);
};

Post.update = function (post_id, params) {
  Post.notice_update("inc");

  TaskQueue.add(() => {
    $.ajax({
      type: "PUT",
      url: "/posts/" + post_id + ".json",
      data: params,
      success: function (data) {
        Post.notice_update("dec");
        Post.update_data(data);
      },
      error: function (data) {
        Post.notice_update("dec");
        const message = $
          .map(data.responseJSON.errors, function (msg) { return msg; })
          .join("; ");
        $(window).trigger("danbooru:error", `There was an error updating <a href="/posts/${post_id}">post #${post_id}</a>: ${message}`);
      },
    });
  }, { name: "Post.update" });
};

Post.delete_with_reason = function (post_id, reason, options = {}) {
  const { reload_after_delete = false, from_flag = false, move_favorites = false,
    dmail = null, dmail_title = null } = options;

  Post.notice_update("inc");
  let error = false;
  TaskQueue.add(() => {
    console.log(`Deleting post ${post_id} for reason: ${reason}`);
    $.ajax({
      type: "POST",
      url: `/staff/post/posts/${post_id}/delete.json`,
      data: {commit: "Delete", reason: reason, from_flag: from_flag, move_favorites: move_favorites,
        dmail: dmail, dmail_title: dmail_title},
    }).fail(function (data) {
      if (data.status === 409) {
        E621.Toast.alert("Post already deleted.");
        location.reload();
        return;
      }
      if (data.responseJSON && data.responseJSON.reason) {
        E621.Toast.alert("Error: " + data.responseJSON.reason);
        error = true;
        return;
      }

      var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
      E621.Toast.alert("Error: " + message);
      error = true;
    }).done(function () {
      E621.Toast.notice("Deleted post.");
      if (reload_after_delete) {
        location.reload();
      } else {
        Post.getMatchingThumbnails(post_id).attr("data-flags", "deleted");
      }
    }).always(function () {
      if (!error)
        Post.notice_update("dec");
    });
  }, { name: "Post.delete_with_reason" });
};

Post.undelete = function (post_id, callback) {
  Post.notice_update("inc");
  TaskQueue.add(() => {
    $.ajax({
      type: "POST",
      url: `/staff/post/posts/${post_id}/undelete.json`,
    }).fail(function (data) {
      //      var message = $.map(data.responseJSON.errors, function(msg, attr) { return msg; }).join('; ');
      const message = data.responseJSON.message;
      E621.Toast.alert("Error: " + message);
    }).done(function () {
      Post.getMatchingThumbnails(post_id).attr("data-flags", "active");
      E621.Toast.notice("Undeleted post.");
      if (callback) callback();
    }).always(function () {
      Post.notice_update("dec");
    });
  }, { name: "Post.undelete" });
};

Post.unflag = function (post_id, approval, reload = true, callback = null) {
  Post.notice_update("inc");
  let modApproval = approval || "none";
  TaskQueue.add(() => {
    $.ajax({
      type: "DELETE",
      url: `/posts/${post_id}/flag.json`,
      data: {approval: modApproval},
    }).fail(function (data) {
      const message = data.responseJSON.message;
      E621.Toast.alert("Error: " + message);
    }).done(function () {
      Post.getMatchingThumbnails(post_id).removeClass("flagged");
      E621.Toast.notice("Unflagged post");
      if (callback) callback();
      if (reload) location.reload();
    }).always(function () {
      Post.notice_update("dec");
    });
  }, { name: "Post.unflag" });
};

Post.flag = function (post_id, reason_name, parent_id = null, note = null, reload = true, callback = null) {
  Post.notice_update("inc");
  TaskQueue.add(() => {
    $.ajax({
      type: "POST",
      url: "/post_flags.json",
      data: {
        post_flag: {
          post_id: parseInt(post_id),
          reason_name,
          parent_id,
          note,
        },
      },
    }).fail(function (data) {
      const message = data.responseJSON.message;
      E621.Toast.alert("Error: " + message);
    }).done(function () {
      E621.Toast.notice("Flagged post");
      if (callback) callback();
      if (reload) location.reload();
    }).always(function () {
      Post.notice_update("dec");
    });
  }, { name: "Post.flag" });
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
  TaskQueue.add(() => {
    $.ajax({
      type: "DELETE",
      url: "/staff/post/approval.json",
      data: {post_id: post_id},
    }).fail(function (data) {
      var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
      E621.Toast.alert("Error: " + message);
    }).done(function () {
      E621.Toast.notice("Unapproved post.");
      location.reload();
    }).always(function () {
      Post.notice_update("dec");
    });
  }, { name: "Post.unapprove" });
};

Post.destroy = function (post_id, reason) {
  $.post(`/staff/post/posts/${post_id}/expunge.json`, { reason },
  ).fail(data => {
    var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
    E621.Toast.alert("Error: " + message);
  }).done(() => {
    location.href = `/staff/destroyed_posts/${post_id}`;
  });
};

Post.regenerate_image_samples = function (post_id) {
  $.post(`/staff/post/posts/${post_id}/regenerate_thumbnails.json`, {},
  ).fail(data => {
    E621.Toast.alert("Error: " + data.responseJSON.reason);
  }).done(() => {
    if ($("#image-container").data("size") >= 10 * 1024 * 1024) {
      E621.Toast.notice("Large file: Image samples will be regenerated soon.");
    } else {
      E621.Toast.notice("Image samples regenerated successfully.");
    }
  });
};

Post.regenerate_video_samples = function (post_id) {
  $.post(`/staff/post/posts/${post_id}/regenerate_videos.json`, {},
  ).fail(data => {
    E621.Toast.alert("Error: " + data.responseJSON.reason);
  }).done(() => {
    E621.Toast.notice("Video samples will be regenerated in a few minutes.");
  });
};

Post.approve = function (post_id, callback) {
  Post.notice_update("inc");
  TaskQueue.add(() => {
    $.post(
      "/staff/post/approval.json",
      { "post_id": post_id },
    ).fail(function (data) {
      var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
      E621.Toast.alert("Error: " + message);
    }).done(function () {
      const $thumbnails = Post.getMatchingThumbnails(post_id);
      if ($thumbnails.length) {
        $thumbnails.data("flags", $thumbnails.data("flags").replace(/pending/, ""));
        $thumbnails.removeClass("pending");
        E621.Toast.notice("Approved post #" + post_id);
      }
      if (callback) {
        callback();
      }
    }).always(function () {
      Post.notice_update("dec");
    });
  }, { name: "Post.approve" });
};

Post.disapprove = function (post_id, reason, message) {
  Post.notice_update("inc");
  TaskQueue.add(() => {
    $.post(
      "/staff/post/disapprovals.json",
      {"post_disapproval[post_id]": post_id, "post_disapproval[reason]": reason, "post_disapproval[message]": message},
    ).fail(function (data) {
      var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
      E621.Toast.alert("Error: " + message);
    }).done(function () {
      if ($("#c-posts #a-show").length) {
        location.reload();
      }
    }).always(function () {
      Post.notice_update("dec");
    });
  }, { name: "Post.disapprove" });
};

Post.update_tag_count = function () {
  let string = "0 tags";
  let count = 0;
  // let count2 = 1;

  const input = $("#post_tag_string");
  if (input.length) {
    let tags = [...new Set(input.val().match(/\S+/g))];
    if (tags) {
      count = tags.length;
      string = (count == 1) ? (count + " tag") : (count + " tags");
    }
  }
  $("#tags-container .count").html(string);

  let klass = "smile";
  if (count < 15) {
    klass = "frown";
  } else if (count < 25) {
    klass = "meh";
  }

  $("#tags-container .options #face")
    .html(SVGIcon.ICONS["face_" + klass])
    .removeClass("face-smile face-frown face-meh")
    .addClass("face-" + klass);
};

Post.vote = function (id, score, prevent_unvote) {
  console.log("Post.vote is deprecated and will be removed at a later date. User PostVote.vote instead.");
  PostVote.vote(id, score, prevent_unvote);
};

Post.set_as_avatar = function (id) {
  TaskQueue.add(() => {
    $.ajax({
      method: "PATCH",
      url: `/users/${CurrentUser.id}.json`,
      data: {
        "user[avatar_id]": id,
      },
      headers: {
        accept: "*/*;q=0.5,text/javascript",
      },
    }).done(function () {
      E621.Toast.notice("Post set as avatar. You can crop it further <a href='/maintenance/user/avatar/edit'>here</a>.");
    });
  }, { name: "Post.set_as_avatar" });
};

$(() => {
  Post.initialize_all();
});

export default Post;
