import Utility from "./utility";
import ZingTouch from "zingtouch";
import Hotkeys from "./hotkeys";
import LStorage from "./utility/storage";
import TaskQueue from "./utility/task_queue";
import PostVote from "./models/PostVote";
import Page from "./utility/page";

let Post = {};

Post.pending_update_count = 0;
Post.resizeMode = "unknown";

Post.initialize_all = function () {

  if ((Page.Controller == "posts" && ["index", "show"].includes(Page.Action)) || Page.Controller == "favorites")
    this.initialize_shortcuts();

  if ($("#c-posts").length) {
    this.initialize_shortcuts();
  }

  if ($("#c-posts").length && $("#a-index").length) {
    this.initialize_gestures();
  }

  if ($("#c-posts").length && $("#a-show").length) {
    this.initialize_links();
    this.initialize_post_relationship_previews();
    this.initialize_post_sections();
    this.initialize_resize();
    this.initialize_gestures();
    this.initialize_moderation();
  }

  this.initialize_collapse();

  $(document).on("danbooru:open-post-edit-tab", () => Hotkeys.enabled = false);
  $(document).on("danbooru:open-post-edit-tab", () => $("#post_tag_string").trigger("focus"));
  $(document).on("danbooru:close-post-edit-tab", () => Hotkeys.enabled = true);

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

    if (confirm("Move flag to parent?"))
      Post.move_flag_to_parent(post_id, parent_id);
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

/**
 * Swipe gesture recognizer that works by averaging the angle/distance/velocity of a gesture path and returning the result.
 * This improves accuracy over the default Swipe gesture, which only uses the last two points to calculate angle/velocity,
 * leading to false detections when a gesture path bends at the end.
 */
class E6Swipe extends ZingTouch.Swipe {
  constructor (options) {
    super(options);
    this.type = "e6swipe";
    this.minDistance = 150;
  }

  end (inputs) {
    function getAngle (a, b) {
      return Math.atan2(b[1] - a[1], b[0] - a[0]);
    }
    function getVelocity (a, b) {
      const dist = distanceBetweenTwoPoints([a[0], a[1]], [b[0], b[1]]);
      return dist / (b[2] - a[2]);
    }
    function distanceBetweenTwoPoints (a, b) {
      return Math.hypot(b[0] - a[0], b[1] - a[1]);
    }

    // Swipe gestures are always exactly one point in size.
    if (this.numInputs !== inputs.length) {
      return null;
    }

    // Prevent gestures from triggering while inputs are active.
    const activeElement = document.activeElement;
    if (activeElement && ["INPUT", "TEXTAREA", "SELECT"].indexOf(activeElement.tagName) !== -1)
      return null;

    let output = {
      data: [],
    };

    const input = inputs[0];
    if (input.current.type !== "end")
      return null;
    const progress = input.getGestureProgress(this.getId());
    // Ensure sufficient move data to compute inputs.
    if (!progress.moves || progress.moves.length <= 2)
      return null;
    const currentMove = progress.moves[progress.moves.length - 1];
    // Has move lingered too long.
    if (new Date().getTime() - currentMove.time > this.maxRestTime)
      return null;
    const totals = progress.moves.reduce(function (acc, move, index) {
      // Skip first element as we can't use it anyways.
      if (index === 0)
        return {vel: 0, angle: [0, 0], dist: 0, last: move};
      const vel = getVelocity([acc.last.x, acc.last.y, acc.last.time], [move.x, move.y, move.time]);
      const angle = getAngle([acc.last.x, acc.last.y], [move.x, move.y]);
      const dist = distanceBetweenTwoPoints([acc.last.x, acc.last.y], [move.x, move.y]);
      return {vel: acc.vel + vel, angle: [acc.angle[0] + Math.cos(angle), acc.angle[1] + Math.sin(angle)], dist: acc.dist + dist, last: move};
    }, {vel: 0, angle: 0, dist: 0, last: null});
    // const initial = input.initial;
    // Add total gesture motion as a bias.
    // totals.vel += getVelocity([initial.x, initial.y, initial.time], [input.current.x, input.current.y, input.current.time]);
    // totals.angle += getAngle([initial.x, initial.y], [input.current.x, input.current.y]) + Math.PI;
    // totals.dist += distanceBetweenTwoPoints([initial.x, initial.y], [input.current.x, input.current.y]);
    const avgMoves = progress.moves.length - 2;
    const averages = {vel: totals.vel / avgMoves, angle: Math.atan2(totals.angle[0], totals.angle[1])};
    output.data[0] = {
      velocity: averages.vel,
      distance: totals.dist,
      duration: 1,
      currentDirection: averages.angle,
    };

    // Minimum velocity requirement.
    if (output.data[0].velocity < this.escapeVelocity)
      return null;
    // Minimum distance requirement. Helps to prevent phantom strokes on bad digitizers.
    if (output.data[0].distance < this.minDistance)
      return null;

    if (output.data.length > 0)
      return output;

    return null;
  }
}

Post.initialize_gestures = function () {
  if (!LStorage.Theme.Gestures) return;
  if (!(("ontouchstart" in window) || (navigator.maxTouchPoints > 0)))
    return;
  // Need activeElement to make sure that this doesn't go off during input.
  if (!("activeElement" in document))
    return;

  const $body = $("body");
  if ($body.data("zing"))
    return;

  const zing = new ZingTouch.Region(document.body, false, false);
  zing.bind(document.body, new E6Swipe(), function (e) {
    const angle = e.detail.data[0].currentDirection * 180 / Math.PI;
    console.log(angle, e.detail.data[0]);
    const hasPrev = Post.has_prev_target();
    const hasNext = Post.has_next_target();
    if (hasPrev && (angle > 90 - 25 && angle < 90 + 25)) { // right swipe
      $("body").css({"transition-timing-function": "ease", "transition-duration": "0.2s", "opacity": "0", "transform": "translateX(150%)"});
      Utility.delay(200).then(() => Post.nav_prev(e));
    }
    if (hasNext && (angle > -90 - 25 && angle < -90 + 25)) { // Left swipe
      $("body").css({"transition-timing-function": "ease", "transition-duration": "0.2s", "opacity": "0", "transform": "translateX(-150%)"});
      Utility.delay(200).then(() => Post.nav_next(e));
    }
  });

  $body.data("zing", zing);
  $("#image-container").css({overflow: "visible"});
};

Post.nav_prev = function () {
  var href = "";

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
  var href = "";

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
          $(window).trigger("danbooru:notice", "Successfully copied notes to <a href='" + other_post_id + "'>post #" + other_post_id + "</a>");
        },
        error: function (data) {
          if (data.status === 404) {
            $(window).trigger("danbooru:error", "Error: Invalid destination post");
          } else if (data.responseJSON && data.responseJSON.reason) {
            $(window).trigger("danbooru:error", "Error: " + data.responseJSON.reason);
          } else {
            $(window).trigger("danbooru:error", "There was an error copying notes to <a href='" + other_post_id + "'>post #" + other_post_id + "</a>");
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

Post.currentPost = function () {
  if (!this._currentPost)
    this._currentPost = this.fromDOM($("#image-container"));
  return this._currentPost;
};

Post.fromDOM = function (element) {
  if (!element)
    return {};

  const post = element.attr("data-post") || "{}";
  return JSON.parse(post);
};

Post.resize_video = function (post, target_size) {
  if (!post || !post.file) return;

  const $video = $("video#image");
  if (!$video.length) return; // Caused by the video being deleted
  const videoTag = $video[0];
  const $notice = $("#image-resize-notice");
  const update_resize_percentage = function (width, orig_width) {
    const $percentage = $("#image-resize-size");
    const scaled_percentage = Math.floor(100 * width / orig_width);
    $percentage.text(`${scaled_percentage}%`);
  };
  $notice.hide();
  let target_sources = [];
  let desired_classes = [];

  switch (target_size) {
    case "source":
      target_sources = calculate_original_sources(post, true);
      break;
    case "original":
      target_sources = calculate_original_sources(post);
      break;
    case "fit":
      target_sources = calculate_original_sources(post);
      desired_classes.push("fit-window");
      break;
    case "fitv":
      target_sources = calculate_original_sources(post);
      desired_classes.push("fit-window-vertical");
      break;
    default: {
      $notice.show();

      const targetVideo = post.sample.alternates?.samples[target_size];
      if (!targetVideo) {
        console.error(`No video found for target size: ${target_size}`);
        return;
      }

      target_sources.push({
        type: "video/mp4; codecs=\"avc1.4D401E\"",
        url: targetVideo?.url,
      });

      desired_classes.push("fit-window");
      update_resize_percentage(targetVideo.width, post.file.width);
      break;
    }
  }

  $video.empty(); // Yank any sources out of the list to prevent browsers from being pants on head.

  let foundPlayable = false;
  for (const source of target_sources) {
    // canPlayType can return "probably", "maybe" or "".
    // * "maybe" means that the browser cannot determine whether it can play the file until playback is attempted.
    // * "probably" indicates that the browser thinks it can play the file, and seems to be returned only if the codec is provided.
    // * "" means that the browser cannot play the file. It will also throw an error in the console.
    if (!videoTag.canPlayType(source.type)) continue;
    foundPlayable = true;

    // No need to reload the video if we are just changing the scale
    if (source.url === $video.attr("src")) break;

    play_video_file(videoTag, source.url);
    break;
  }

  // Fallback if no playable source was found.
  if (!foundPlayable) play_video_file(videoTag, post.file.url);

  // Adjust the classes last, to prevent video from
  // getting resized before the source is set.
  $video.removeClass();
  for (const class_name of desired_classes) {
    $video.addClass(class_name);
  }
};

/** Collates the non-downscaled video sources */
function calculate_original_sources (post, skipVariants = LStorage.Posts.SkipVariants) {
  if (!post || !post.file || !post.sample?.alternates) return [];

  const result = [];

  // Add the original file first.
  // Unprocessed posts will not have a codec string on file, which makes feature detection harder
  let originalCodec = post.sample.alternates?.original?.codec;
  result.push({
    type: originalCodec ? `video/${post.file.ext}; codecs="${originalCodec}"` : `video/${post.file.ext}`,
    url: post.file.url,
  });

  // Add fallback variants if they exist.
  // The "Source" view does not display these.
  if (post.sample.alternates.variants && !skipVariants)
    for (const [filetype, data] of Object.entries(post.sample.alternates.variants)) {
      if (!data.url) continue;
      result.push({
        type: `video/${filetype}; codecs="${data.codec}"`,
        url: data.url,
      });
    }

  return result;
}

/**
 * Plays a video file in the specified video tag.
 * @param {HTMLVideoElement} videoTag HTML tag of the video player
 * @param {string} sourceURL New video source URL
 */
function play_video_file (videoTag, sourceURL) {
  const wasPaused = videoTag.paused;
  if (!wasPaused) videoTag.pause(); // Otherwise size changes won't take effect.
  const time = videoTag.currentTime;

  videoTag.setAttribute("src", sourceURL);
  videoTag.load(); // Forces changed source to take effect. *SOME* browsers ignore changes otherwise.

  // Resume playback at the original time
  videoTag.currentTime = time;
  if (!wasPaused) videoTag.play();
}

Post.resize_image = function (post, target_size) {
  const $image = $("img#image");
  const $notice = $("#image-resize-notice");
  const update_resize_percentage = function (width, orig_width) {
    const $percentage = $("#image-resize-size");
    const scaled_percentage = Math.floor(100 * width / orig_width);
    $percentage.text(`${scaled_percentage}%`);
  };
  $notice.hide();
  let desired_url = "";
  let desired_classes = [];
  switch (target_size) {
    case "original":
      desired_url = post?.file?.url;
      break;
    case "fit":
      desired_classes.push("fit-window");
      desired_url = post?.file?.url;
      break;
    case "fitv":
      desired_classes.push("fit-window-vertical");
      desired_url = post?.file?.url;
      break;
    case "large":
      $notice.show();
      desired_classes.push("fit-window");
      desired_url = post?.sample?.url;
      update_resize_percentage(post?.sample?.width, post?.file?.width);
      break;
    default:
      $notice.show();
      desired_classes.push("fit-window");
      desired_url = post?.sample?.alternates[target_size]?.url;
      update_resize_percentage(post?.sample?.alternates[target_size]?.width, post?.file?.width);
      break;
  }
  $image.removeClass();
  if ($image.attr("src") !== desired_url) {
    $("#image-container").addClass("image-loading");
    $image.attr("src", desired_url);
  }
  for (const class_name of desired_classes) {
    $image.addClass(class_name);
  }
};

Post.resize_to = function (target_size) {
  target_size = update_size_selector(target_size);

  const post = Post.currentPost();
  if (is_video(post)) {
    Post.resize_video(post, target_size);
  } else {
    Post.resize_image(post, target_size);
  }
};


function is_video (post) {
  switch (post.file.ext) {
    case "webm":
    case "mp4":
      return true;
    default:
      return false;
  }
}

function update_size_selector (choice) {
  const selector = $("#image-resize-selector");
  const choices = selector.find("option");
  if (choice === "next") {
    const index = selector[0].selectedIndex;
    const next_choice = $(choices[(index + 1) % choices.length]).val();
    selector.val(next_choice);
    return next_choice;
  }
  for (const item of choices) {
    if ($(item).val() == choice) {
      selector.val(choice);
      return choice;
    }
  }
  selector.val("fit");
  return "fit";
}

function most_relevant_sample_size () {
  const sampleList = Post.currentPost().sample?.alternates?.samples;
  if (!sampleList) return "fitv";

  const samples = Object.entries(sampleList);
  if (samples.length === 0) return "fitv";

  const fitWidth = $("#image-container").width(),
    fitHeight = window.outerHeight;

  let latest = "fitv";
  for (const [name, data] of samples.reverse()) {
    latest = name;
    if ((fitHeight - data.height) < 0 || (fitWidth - data.width) < 0) continue;
    return name;
  }
  return latest;
}

Post.initialize_resize = function () {
  Post.initialize_change_resize_mode_link();
  const post = Post.currentPost();
  if (post?.file?.ext === "swf")
    return;

  const is_post_video = is_video(post);
  if (!is_post_video) {
    const $image = $("img#image");

    $image.on("load", function () {
      $("#image-container").removeClass("image-loading");
    });
  }
  let image_size = Utility.meta("image-override-size") || Utility.meta("default-image-size");
  if (is_post_video && image_size === "large") {
    image_size = most_relevant_sample_size();
  }
  Post.resize_to(image_size);
  const $selector = $("#image-resize-selector");
  $selector.on("change", () => Post.resize_to($selector.val()));
};

Post.resize_cycle_mode = function () {
  Post.resize_to("next");
};

Post.initialize_change_resize_mode_link = function () {
  $("#image-resize-link").on("click", (e) => {
    e.preventDefault();
    Post.resize_to("fit");
  }); // For top panel

  Hotkeys.register("resize", Post.resize_cycle_mode);
};

Post.initialize_post_sections = function () {
  $("#post-sections li a,#side-edit-link").on("click.danbooru", function (e) {
    if (e.target.hash === "#comments") {
      $("#comments").show();
      $("#edit").hide();
    } else if (e.target.hash === "#edit") {
      $("#edit").show();
      $("#comments").hide();
      $(document).trigger("danbooru:open-post-edit-tab");
      Post.update_tag_count({target: $("#post_tag_string")});
    } else {
      $("#edit").hide();
      $("#comments").hide();
    }

    if (e.target.hash !== "#edit") {
      $(document).trigger("danbooru:close-post-edit-tab");
    }

    $("#post-sections li").removeClass("active");
    $(e.target).parent("li").addClass("active");
    e.preventDefault();
  });
};

Post.notice_update = function (x) {
  if (x === "inc") {
    Post.pending_update_count += 1;
    $(window).trigger("danbooru:notice", "Updating posts (" + Post.pending_update_count + " pending)...", true);
  } else {
    Post.pending_update_count -= 1;

    if (Post.pending_update_count < 1) {
      $(window).trigger("danbooru:notice", "Posts updated");
    } else {
      $(window).trigger("danbooru:notice", "Updating posts (" + Post.pending_update_count + " pending)...", true);
    }
  }
};

Post.update_data = function (data) {
  var $post = $("#post_" + data.id);
  $post.attr("data-tags", data.tag_string);
  $post.data("rating", data.rating);
  $post.removeClass("post-status-has-parent post-status-has-children");
  if (data.parent_id) {
    $post.addClass("post-status-has-parent");
  }
  if (data.has_visible_children) {
    $post.addClass("post-status-has-children");
  }
};

Post.tag = function (post_id, tags) {
  const tag_string = (Array.isArray(tags) ? tags.join(" ") : String(tags));
  Post.update(post_id, { "post[old_tag_string]": "", "post[tag_string]": tag_string });
};

Post.tagScript = function (post_id, tags) {
  const tag_string = (Array.isArray(tags) ? tags.join(" ") : String(tags));
  Post.update(post_id, { "post[tag_string_diff]": tag_string });
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
  const { reload_after_delete = false, move_favorites = false } = options;

  Post.notice_update("inc");
  let error = false;
  TaskQueue.add(() => {
    $.ajax({
      type: "POST",
      url: `/moderator/post/posts/${post_id}/delete.json`,
      data: {commit: "Delete", reason: reason, move_favorites: move_favorites},
    }).fail(function (data) {
      if (data.responseJSON && data.responseJSON.reason) {
        $(window).trigger("danbooru:error", "Error: " + data.responseJSON.reason);
        error = true;
        return;
      }

      var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
      $(window).trigger("danbooru:error", "Error: " + message);
      error = true;
    }).done(function () {
      $(window).trigger("danbooru:notice", "Deleted post.");
      if (reload_after_delete) {
        location.reload();
      } else {
        $(`article#post_${post_id}`).attr("data-flags", "deleted");
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
      url: `/moderator/post/posts/${post_id}/undelete.json`,
    }).fail(function (data) {
      //      var message = $.map(data.responseJSON.errors, function(msg, attr) { return msg; }).join('; ');
      const message = data.responseJSON.message;
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(function () {
      $(window).trigger("danbooru:notice", "Undeleted post.");
      $(`article#post_${post_id}`).attr("data-flags", "active");
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
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(function () {
      $(window).trigger("danbooru:notice", "Unflagged post");
      if (callback) callback();
      if (reload) location.reload();
    }).always(function () {
      Post.notice_update("dec");
    });
  }, { name: "Post.unflag" });
};

Post.flag = function (post_id, reason_name, parent_id = null, reload = true, callback = null) {
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
        },
      },
    }).fail(function (data) {
      const message = data.responseJSON.message;
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(function () {
      $(window).trigger("danbooru:notice", "Flagged post");
      if (callback) callback();
      if (reload) location.reload();
    }).always(function () {
      Post.notice_update("dec");
    });
  }, { name: "Post.flag" });
};

Post.move_flag_to_parent = function (post_id, parent_id) {
  Post.unflag(post_id, false, false, function () {
    Post.flag(parent_id, "inferior", post_id, false, function () {
      location.href = `/moderator/post/posts/${parent_id}/confirm_delete`;
    });
  });
};


Post.unapprove = function (post_id) {
  Post.notice_update("inc");
  TaskQueue.add(() => {
    $.ajax({
      type: "DELETE",
      url: "/moderator/post/approval.json",
      data: {post_id: post_id},
    }).fail(function (data) {
      var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(function () {
      $(window).trigger("danbooru:notice", "Unapproved post.");
      location.reload();
    }).always(function () {
      Post.notice_update("dec");
    });
  }, { name: "Post.unapprove" });
};

Post.destroy = function (post_id, reason) {
  $.post(`/moderator/post/posts/${post_id}/expunge.json`, { reason },
  ).fail(data => {
    var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
    $(window).trigger("danbooru:error", "Error: " + message);
  }).done(() => {
    location.href = `/admin/destroyed_posts/${post_id}`;
  });
};

Post.regenerate_image_samples = function (post_id) {
  $.post(`/moderator/post/posts/${post_id}/regenerate_thumbnails.json`, {},
  ).fail(data => {
    Utility.error("Error: " + data.responseJSON.reason);
  }).done(() => {
    if ($("#image-container").data("size") >= 10 * 1024 * 1024) {
      Utility.notice("Large file: Image samples will be regenerated soon.");
    } else {
      Utility.notice("Image samples regenerated successfully.");
    }
  });
};

Post.regenerate_video_samples = function (post_id) {
  $.post(`/moderator/post/posts/${post_id}/regenerate_videos.json`, {},
  ).fail(data => {
    Utility.error("Error: " + data.responseJSON.reason);
  }).done(() => {
    Utility.notice("Video samples will be regenerated in a few minutes.");
  });
};

Post.approve = function (post_id, callback) {
  Post.notice_update("inc");
  TaskQueue.add(() => {
    $.post(
      "/moderator/post/approval.json",
      { "post_id": post_id },
    ).fail(function (data) {
      var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
      Danbooru.error("Error: " + message);
    }).done(function () {
      var $post = $("#post_" + post_id);
      if ($post.length) {
        $post.data("flags", $post.data("flags").replace(/pending/, ""));
        $post.removeClass("post-status-pending");
        Danbooru.notice("Approved post #" + post_id);
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
      "/moderator/post/disapprovals.json",
      {"post_disapproval[post_id]": post_id, "post_disapproval[reason]": reason, "post_disapproval[message]": message},
    ).fail(function (data) {
      var message = $.map(data.responseJSON.errors, (msg) => msg).join("; ");
      $(window).trigger("danbooru:error", "Error: " + message);
    }).done(function () {
      if ($("#c-posts #a-show").length) {
        location.reload();
      }
    }).always(function () {
      Post.notice_update("dec");
    });
  }, { name: "Post.disapprove" });
};

Post.update_tag_count = function (event) {
  let string = "0 tags";
  let count = 0;
  // let count2 = 1;

  if (event) {
    let tags = [...new Set($(event.target).val().match(/\S+/g))];
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
  $("#tags-container .options #face").removeClass().addClass(`fa-regular fa-face-${klass}`);
};

Post.vote = function (id, score, prevent_unvote) {
  console.log("Post.vote is deprecated and will be removed at a later date. User PostVote.vote instead.");
  PostVote.vote(id, score, prevent_unvote);
};

Post.set_as_avatar = function (id) {
  TaskQueue.add(() => {
    $.ajax({
      method: "PATCH",
      url: `/users/${Utility.meta("current-user-id")}.json`,
      data: {
        "user[avatar_id]": id,
      },
      headers: {
        accept: "*/*;q=0.5,text/javascript",
      },
    }).done(function () {
      $(window).trigger("danbooru:notice", "Post set as avatar");
    });
  }, { name: "Post.set_as_avatar" });
};

$(() => {
  Post.initialize_all();
});

export default Post;
