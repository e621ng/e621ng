import DText from "./dtext";
import Utility from "./utility";

let Comment = {};

Comment.initialize_all = function () {
  if ($("#c-posts").length || $("#c-comments").length) {
    $(".edit_comment_link").on("click", Comment.show_edit_form);
    $(".expand-comment-response").on("click", Comment.show_new_comment_form);
    $(".comment-vote-up-link").on("click", Comment.vote_up);
    $(".comment-vote-down-link").on("click", Comment.vote_down);
    $(".comment-reply-link").on("click", Comment.quote);
    $(".comment-hide-link").on("click", Comment.hide);
    $(".comment-unhide-link").on("click", Comment.unhide);
    $(".comment-delete-link").on("click", Comment.delete);
    $(".show-all-comments-for-post-link").on("click", Comment.show_all);
    $(".comment-tag-hide-link").on("click", Comment.toggle_post_tags);
  }
};

Comment.reinitialize_all = function () {
  if ($("#c-posts").length || $("#c-comments").length) {
    $(".comment-reply-link").off("click");
    $(".comment-hide-link").off("click");
    $(".comment-unhide-link").off("click");
    $(".comment-delete-link").off("click");
    $(".show-all-comments-for-post-link").off("click");
    $(".comment-tag-hide-link").off("click");
    $(".edit_comment_link").off("click");
    $(".expand-comment-response").off("click");
    $(".comment-vote-up-link").off("click");
    $(".comment-vote-down-link").off("click");
    Comment.initialize_all();
    DText.initialize_all_inputs();
  }
};

Comment.show_all = function (e) {
  e.preventDefault();
  const target = $(e.target);
  const post_id = target.data("pid");
  $.ajax({
    url: `/posts/${post_id}/comments.json`,
    type: "GET",
    dataType: "json",
  }).done(function (data) {
    $(`#threshold-comments-notice-for-${post_id}`).hide();

    const current_comment_section = $(`div.comments-for-post[data-post-id=${post_id}] div.list-of-comments`);
    current_comment_section.html(data.html);
    Comment.reinitialize_all();
    $(window).trigger("e621:add_deferred_posts", data.posts);
  }).fail(function () {
    Utility.error("Failed to fetch all comments for this post.");
  });
};

Comment.hide = function (e) {
  e.preventDefault();
  if (!confirm("Are you sure you want to hide this comment?"))
    return;
  const parent = $(e.target).parents("article.comment");
  const cid = parent.data("comment-id");
  $.ajax({
    url: `/comments/${cid}/hide.json`,
    type: "POST",
    dataType: "json",
  }).done(function () {
    $(`.comment[data-comment-id="${cid}"] div.author h1`).append(" (hidden)");
    $(`.comment[data-comment-id="${cid}"]`).attr("data-is-deleted", "true");
  }).fail(function () {
    Utility.error("Failed to hide comment.");
  });
};

Comment.unhide = function (e) {
  e.preventDefault();
  if (!confirm("Are you sure you want to unhide this comment?"))
    return;
  const parent = $(e.target).parents("article.comment");
  const cid = parent.data("comment-id");
  $.ajax({
    url: `/comments/${cid}/unhide.json`,
    type: "POST",
    dataType: "json",
  }).done(function () {
    const $author = $(`.comment[data-comment-id="${cid}"] div.author h1`);
    $author.text($author.text().replace(" (hidden)", ""));
    $(`.comment[data-comment-id="${cid}"]`).attr("data-is-deleted", "false");
  }).fail(function () {
    Utility.error("Failed to unhide comment.");
  });
};

Comment.delete = function (e) {
  e.preventDefault();
  if (!confirm("Are you sure you want to permanently delete this comment?"))
    return;
  const parent = $(e.target).parents("article.comment");
  const cid = parent.data("comment-id");
  $.ajax({
    url: `/comments/${cid}.json`,
    type: "DELETE",
    dataType: "json",
  }).done(function () {
    parent.remove();
  }).fail(function () {
    Utility.error("Failed to delete comment.");
  });
};

Comment.quote = function (e) {
  e.preventDefault();
  const parent = $(e.target).parents("article.comment");
  const pid = parent.data("post-id");
  const cid = parent.data("comment-id");
  $.ajax({
    url: `/comments/${cid}.json`,
    type: "GET",
    dataType: "json",
    accept: "text/javascript",
  }).done(function (data) {
    let stripped_body = data.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\][\n\r]*/gm, "");
    stripped_body = `[quote]"${parent.data("creator")}":/users/${parent.data("creator-id")} said:
${stripped_body}
[/quote]

`;
    var $div = $(`div.comments-for-post[data-post-id="${pid}"] div.new-comment`);
    $div.find(".expand-comment-response").click();

    var $textarea = $div.find("textarea");
    var msg = stripped_body;
    if ($textarea.val().length > 0) {
      msg = $textarea.val() + "\n\n" + msg;
    }

    $textarea.val(msg);
    $textarea.selectEnd();
  }).fail(function (data) {
    Utility.error(data.responseText);
  });
};

Comment.toggle_post_tags = function (e) {
  e.preventDefault();
  const link = $(e.target);
  $(`#post-tags-${link.data("post-id")}`).toggleClass("hidden");
};

Comment.show_new_comment_form = function (e) {
  e.preventDefault();
  $(e.target).hide();
  var $form = $(e.target).closest("div.new-comment").find("form");
  $form.show();
  $form[0].scrollIntoView(false);
};

Comment.show_edit_form = function (e) {
  e.preventDefault();
  $(this).closest(".comment").find(".edit_comment").show();
};

Comment.vote_up = function (e) {
  var id = $(e.target).attr("data-id");
  Comment.vote(id, 1);
};

Comment.vote_down = function (e) {
  var id = $(e.target).attr("data-id");
  Comment.vote(id, -1);
};

Comment.vote = function (id, score) {
  $.ajax({
    method: "POST",
    url: `/comments/${id}/votes.json`,
    data: {
      score: score,
    },
    dataType: "json",
  }).done(function (data) {
    const scoreClasses = "score-neutral score-positive score-negative";
    const commentID = id;
    const commentScore = data.score;
    const ourScore = data.our_score;
    function scoreToClass (inScore) {
      if (inScore === 0) return "score-neutral";
      return inScore > 0 ? "score-positive" : "score-negative";
    }
    $("#comment-score-" + commentID).removeClass(scoreClasses);
    $("#comment-vote-up-" + commentID).removeClass(scoreClasses);
    $("#comment-vote-down-" + commentID).removeClass(scoreClasses);
    $("#comment-score-" + commentID).text(commentScore);
    $("#comment-score-" + commentID).addClass(scoreToClass(commentScore));
    $("#comment-vote-up-" + commentID).addClass(ourScore > 0 ? "score-positive" : "score-neutral");
    $("#comment-vote-down-" + commentID).addClass(ourScore < 0 ? "score-negative" : "score-neutral");
    Utility.notice("Vote saved");
  }).fail(function (data) {
    Utility.error(data.responseJSON.message);
  });
};

$(document).ready(function () {
  Comment.initialize_all();
});

export default Comment;
