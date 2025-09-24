import Utility from "./utility.js";

let Takedown = {};

Takedown.destroy = function (id) {
  Utility.notice("Deleting takedown #" + id + "...");

  $.ajax({
    url: "/takedown/destroy.json",
    type: "POST",
    dataType: "json",
    headers: {accept: "text/javascript"},
    data: {
      "id": id,
    },
  }).done(function () {
    Utility.notice("Takedown deleted");
    $("#takedown-" + id).fadeOut("fast");
  }).fail(function (data) {
    Utility.error(data.responseText);
  });
};

Takedown.add_posts_by_tags_preview = function (id) {
  const tags = $("#takedown-add-posts-tags").val();
  $.ajax({
    url: "/takedowns/count_matching_posts.json",
    type: "POST",
    dataType: "json",
    headers: {accept: "text/javascript"},
    data: {
      id: id,
      post_tags: tags,
    },
  }).done(function (data) {
    var count = data.matched_post_count;
    var preview_text = "<a href='/post/index?tags=" + tags.replace(" ", "+") + "+status:any'>" + count + " " + (count == 1 ? "post" : "posts") + "</a> " + (count == 1 ? "matches" : "match") + " the search '<a href='/post/index?tags=" + tags.replace(" ", "+") + "+status:any'>" + tags + "</a>'. Click Confirm to add " + (count == 1 ? "it" : "them") + " to the takedown.";

    $("#takedown-add-posts-tags-warning").html(preview_text).show();
    $("#takedown-add-posts-tags").prop("disabled", true);
    $("#takedown-add-posts-tags-preview").hide();
    $("#takedown-add-posts-tags-confirm").css("display", "inline-block");
    $("#takedown-add-posts-tags-cancel").css("display", "inline-block");
  }).fail(function (data) {
    Utility.error(data.responseText);
  });
};

Takedown.add_posts_by_tags_cancel = function () {
  $("#takedown-add-posts-tags-warning").hide();
  $("#takedown-add-posts-tags").val("").prop("disabled", false);
  $("#takedown-add-posts-tags-preview").show().prop("disabled", true);
  $("#takedown-add-posts-tags-confirm").hide();
  $("#takedown-add-posts-tags-cancel").hide();
};

Takedown.add_posts_by_tags = function (id) {
  event.preventDefault();
  const tags = $("#takedown-add-posts-tags").val();
  Utility.notice("Adding posts with tags '" + tags + "' to takedown...");

  $.ajax({
    url: `/takedowns/${id}/add_by_tags.json`,
    type: "POST",
    dataType: "json",
    headers: {accept: "text/javascript"},
    data: {
      id: id,
      post_tags: tags,
    },
  }).done(function (data) {
    const added_post_ids = data.added_post_ids;
    const count = added_post_ids.length;

    Utility.notice(count + " post" + (count == 1 ? "" : "s") + " with tags '" + tags + "' added to takedown");

    for (var i = 0; i < count; i++) {
      var html = Takedown.post_button_html(added_post_ids[i]);
      $(html).appendTo($("#takedown-post-buttons"));
    }

    $("#takedown-add-posts-tags-submit").prop("disabled", true);
    Takedown.add_posts_by_tags_cancel();
  }).fail(function (data) {
    Utility.error(data.responseText);
  });
};

Takedown.add_posts_by_ids = function (id) {
  event.preventDefault();
  const post_ids = $("#takedown-add-posts-ids").val();
  Utility.notice("Adding posts to takedown...");

  $.ajax({
    url: `/takedowns/${id}/add_by_ids.json`,
    type: "POST",
    dataType: "json",
    headers: {accept: "text/javascript"},
    data: {
      id: id,
      post_ids: post_ids,
    },
  }).done(function (data) {
    Utility.notice(data.added_count + " post" + (data.added_count == 1 ? "" : "s") + " added to takedown");

    var added_post_ids = data.added_post_ids;
    for (var i = 0; i < added_post_ids.length; i++) {
      var html = Takedown.post_button_html(added_post_ids[i]);
      $(html).appendTo($("#takedown-post-buttons"));
    }

    $("#takedown-add-posts-ids").val("");
    $("#takedown-add-posts-ids-submit").prop("disabled", true);
  }).fail(function (data) {
    Utility.error(data.responseText);
  });
};

Takedown.remove_post = function (id, post_id) {
  Utility.notice("Removing post #" + post_id + " from takedown...");

  $.ajax({
    url: `/takedowns/${id}/remove_by_ids.json`,
    type: "POST",
    dataType: "json",
    headers: {accept: "text/javascript"},
    data: {
      id: id,
      post_ids: post_id,
    },
  }).done(function () {
    Utility.notice("Post #" + post_id + " removed from takedown");
    $("#takedown-post-" + post_id).remove();
  }).fail(function (data) {
    Utility.error(data.responseText);
  });
};

Takedown.post_button_html = function (post_id) {
  return "<div id='takedown-post-" + post_id + "' data-post-id='" + post_id + "' class='takedown-post'><div class='takedown-post-label takedown-post-remove' title='Remove this post from the takedown'>X</div> <label for='takedown_posts_" + post_id + "' class='takedown-post-label takedown-post-keep'><input name='takedown_posts[" + post_id + "]' type='hidden' value='0'><input id='takedown_posts_" + post_id + "' name='takedown_posts[" + post_id + "]' type='checkbox' value='1'> <span>Keep</span></label> <a href='/post/show/" + post_id + "'>post #" + post_id + "</a></div>";
};

$(document).ready(function () {
  $("#takedown-add-posts-ids-submit").on("click", e => {
    const $e = $(e.target);
    Takedown.add_posts_by_ids($e.data("tid"));
  });
  $("#takedown-add-posts-tags-cancel").on("click", () => {
    Takedown.add_posts_by_tags_cancel();
  });
  $("#takedown-add-posts-tags-confirm").on("click", e => {
    const $e = $(e.target);
    Takedown.add_posts_by_tags($e.data("tid"));
  });
  $("#takedown-add-posts-tags-preview").on("click", e => {
    const $e = $(e.target);
    Takedown.add_posts_by_tags_preview($e.data("tid"));
  });
});

export default Takedown;
