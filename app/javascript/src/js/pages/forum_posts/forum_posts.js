import TextUtils from "@/utility/text_util";

let ForumPost = {};

ForumPost.initialize_all = function () {
  if ($("#c-forum-topics #a-show,#c-forum-posts #a-show").length) {
    $(".edit_forum_post_link").on("click.danbooru", function (e) {
      var link_id = $(this).attr("id");
      var forum_post_id = link_id.match(/^edit_forum_post_link_(\d+)$/)[1];
      $("#edit_forum_post_" + forum_post_id).fadeToggle("fast");
      e.preventDefault();
    });

    $(".edit_forum_topic_link").on("click.danbooru", function (e) {
      var link_id = $(this).attr("id");
      var forum_topic_id = link_id.match(/^edit_forum_topic_link_(\d+)$/)[1];
      $("#edit_forum_topic_" + forum_topic_id).fadeToggle("fast");
      e.preventDefault();
    });

    $(".forum-post-reply-link").on("click", ForumPost.quote);
    $(".forum-post-hide-link").on("click", ForumPost.hide);
    $(".forum-post-unhide-link").on("click", ForumPost.unhide);
  }
};

ForumPost.reinitialize_all = function () {
  if ($("#c-forum-topics #a-show,#c-forum-posts #a-show").length) {
    $(".edit_forum_post_link").off("click.danbooru");
    $(".edit_forum_topic_link").off("click.danbooru");
    $(".forum-post-reply-link").off("click");
    $(".forum-post-hide-link").off("click");
    $(".forum-post-unhide-link").off("click");
    this.initialize_all();
  }
};

ForumPost.quote = function (e) {
  e.preventDefault();
  const parent = $(e.target).parents("article.forum-post");
  const fpid = parent.data("forum-post-id");
  $.ajax({
    url: `/forum_posts/${fpid}.json`,
    type: "GET",
    dataType: "json",
    accept: "text/javascript",
  }).done(function (data) {
    const $textarea = $("#forum_post_body_for_");
    TextUtils.processQuote($textarea, data.body, parent.data("creator"), parent.data("creator-id"));
    $textarea.selectEnd();

    $("#topic-response").show();
    setTimeout(function () {
      $("#topic-response")[0].scrollIntoView();
    }, 15);
  }).fail(function (data) {
    E621.Toast.alert(data.responseText);
  });
};

ForumPost.hide = function (e) {
  e.preventDefault();
  if (!confirm("Are you sure you want to hide this post?"))
    return;
  const parent = $(e.target).parents("article.forum-post");
  const fpid = parent.data("forum-post-id");
  $.ajax({
    url: `/forum_posts/${fpid}/hide.json`,
    type: "POST",
    dataType: "json",
  }).done(function () {
    $(`.forum-post[data-forum-post-id="${fpid}"] div.author h4`).append(" (hidden)");
    $(`.forum-post[data-forum-post-id="${fpid}"]`).attr("data-is-hidden", "true");
  }).fail(function () {
    E621.Toast.alert("Failed to hide post.");
  });
};

ForumPost.unhide = function (e) {
  e.preventDefault();
  if (!confirm("Are you sure you want to unhide this post?"))
    return;
  const parent = $(e.target).parents("article.forum-post");
  const fpid = parent.data("forum-post-id");
  $.ajax({
    url: `/forum_posts/${fpid}/unhide.json`,
    type: "POST",
    dataType: "json",
  }).done(function () {
    const $author = $(`.forum-post[data-forum-post-id="${fpid}"] div.author h4`);
    $author.text($author.text().replace(" (hidden)", ""));
    $(`.forum-post[data-forum-post-id="${fpid}"]`).attr("data-is-hidden", "false");
  }).fail(function () {
    E621.Toast.alert("Failed to unhide post.");
  });
};

$(document).ready(function () {
  ForumPost.initialize_all();
  $(window).on("e621:warnable:reinitialize", ForumPost.reinitialize_all);
});

export default ForumPost;
