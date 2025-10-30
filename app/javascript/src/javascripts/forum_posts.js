import Utility from "./utility";
import TextUtils from "./utility/text_util";

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
    $(".forum-vote-up").on("click", evt => ForumPost.vote(evt, 1));
    $(".forum-vote-meh").on("click", evt => ForumPost.vote(evt, 0));
    $(".forum-vote-down").on("click", evt => ForumPost.vote(evt, -1));
    $(document).on("click", ".forum-vote-remove", ForumPost.vote_remove);
  }
};

ForumPost.reinitialize_all = function () {
  if ($("#c-forum-topics #a-show,#c-forum-posts #a-show").length) {
    $(".edit_forum_post_link").off("click.danbooru");
    $(".edit_forum_topic_link").off("click.danbooru");
    $(".forum-post-reply-link").off("click");
    $(".forum-post-hide-link").off("click");
    $(".forum-post-unhide-link").off("click");
    $(".forum-vote-up").off("click");
    $(".forum-vote-meh").off("click");
    $(".forum-vote-down").off("click");
    $(document).off("click", ".forum-vote-remove");
    this.initialize_all();
  }
};

ForumPost.vote = function (evt, score) {
  evt.preventDefault();
  const create_post = function (new_vote) {
    const score_map = {
      "1": { fa_class:  "fa-thumbs-up", e6_class: "up" },
      "0": { fa_class:  "fa-face-meh", e6_class: "meh" },
      "-1": { fa_class:  "fa-thumbs-down", e6_class: "down" },
    };
    const icon = $("<a>").attr("href", "#").attr("data-forum-id", new_vote.forum_post_id).addClass("forum-vote-remove").append($("<i>").addClass("fa-regular").addClass(score_map[new_vote.score.toString()].fa_class));
    const username = $("<a>").attr("href", `/users/${new_vote.creator_id}`).text(new_vote.creator_name);
    const container = $("<li>").addClass(`vote-score-${score_map[new_vote.score].e6_class}`).addClass("own-forum-vote");
    container.append(icon).append(" ").append(username);
    $(`#forum-post-votes-for-${new_vote.forum_post_id}`).prepend(container);
  };
  const id = $(evt.currentTarget).data("forum-id");
  $.ajax({
    url: `/forum_posts/${id}/votes.json`,
    type: "POST",
    dataType: "json",
    accept: "text/javascript",
    data: { "forum_post_vote[score]": score },
  }).done(function (data) {
    create_post(data);
    $(`#forum-post-votes-for-${id} .forum-post-vote-block`).hide();
  }).fail(function (data) {
    if (data?.responseJSON?.reason) {
      Utility.error(data.responseJSON.reason);
    } else {
      Utility.error("Failed to vote on forum post.");
    }
  });
};

ForumPost.vote_remove = function (evt) {
  evt.preventDefault();
  const id = $(evt.currentTarget).data("forum-id");
  $.ajax({
    url: `/forum_posts/${id}/votes.json`,
    type: "DELETE",
    dataType: "json",
    accept: "text/javascript",
  }).done(function () {
    $(evt.target).parents(".own-forum-vote").remove();
    $(`#forum-post-votes-for-${id} .forum-post-vote-block`).show();
    Utility.notice("Vote removed.");
  }).fail(function () {
    Utility.error("Failed to unvote on forum post.");
  });
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
    Utility.error(data.responseText);
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
    Utility.error("Failed to hide post.");
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
    Utility.error("Failed to unhide post.");
  });
};

$(document).ready(function () {
  ForumPost.initialize_all();
});

export default ForumPost;
