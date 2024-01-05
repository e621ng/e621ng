import DText from "./dtext";
import UserWarnable from "./user_warning";
import Utility from "./utility";

let Comment = {};

Comment.initialize_all = function () {
  if (!$("#c-posts").length && !$("#c-comments").length) return;

  // Logged in only – fallback redirects guests to the login page
  if (!$("meta[name='current-user-id']").attr("content")) return;

  $(".comments-for-post")
    .on("click", ".comment-vote-link", Comment.vote_handler)
    .on("click", ".comment-reply-link", Comment.reply)
    .on("click", ".comment-edit-link", Comment.toggle_edit)
    .on("click", ".comment-edit .comment-edit-cancel", Comment.toggle_edit)
    .on("click", ".comment-delete-link", Comment.delete)
    .on("click", ".comment-undelete-link", Comment.undelete)
    .on("click", ".comment-mark-link", Comment.toggle_mark)
    .on("click", ".comment-destroy-link", Comment.destroy);

  $(".show-all-comments-for-post-link").on("click", Comment.show_all);
}

Comment.reinitialize_all = function () {
  if (!$("#c-posts").length && !$("#c-comments").length) return;

  $(".comments-for-post").off("click");
  $(".show-all-comments-for-post-link").off("click");

  Comment.initialize_all();
  DText.initialize_all_inputs();

}

/**
 * Handles the action of clicking on one of the vote buttons.
 * @param {Event} event Click event
 */
Comment.vote_handler = function (event) {
  event.preventDefault();
  const target = $(event.currentTarget);
  Comment.vote(target.data("comment"), target.data("action"));
}

/**
 * Applies a vote to the specified comment.  
 * Note that if the comment had already been voted on,
 * the vote will be removed instead.
 * @param {number} commentID Comment to vote on.
 * @param {1|-1} action 1 to upvote, -1 to downvote.
 */
Comment.vote = function (commentID, action) {
  $.ajax({
    method: "POST",
    url: `/comments/${commentID}/votes.json`,
    data: {
      score: action
    },
    dataType: "json"
  }).done((data) => {
    $(`.comment-vote[data-id="${commentID}"]`)
      .attr({
        "data-vote": scoreToClass(data.our_score),
        "data-score": data.score,
      })
      .find(".comment-score")
      .text(data.score)
      .removeClass("score-neutral score-positive score-negative")
      .addClass("score-" + scoreToClass(data.score));

    function scoreToClass(num) {
      if (num === 0) return "neutral";
      return num > 0 ? "positive" : "negative";
    }
  }).fail(function (data) {
    Utility.error(data.responseJSON.message ? data.responseJSON.message : "Unable to save the vote.");
  });
}

/**
 * Handles the click on the "Reply" button.  
 * Adds a quote section to the new comment form.
 * @param {Event} event Click event
 */
Comment.reply = function (event) {
  event.preventDefault();
  const parent = $(event.target).parents("article.comment");
  const pid = parent.data('post-id');
  const cid = parent.data('comment-id');
  $.ajax({
    url: `/comments/${cid}.json`,
    type: 'GET',
    dataType: 'json',
    accept: 'text/javascript'
  }).done(function (data) {
    let stripped_body = data.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\][\n\r]*/gm, "");
    stripped_body = `[quote]"${parent.data('creator')}":/users/${parent.data('creator-id')} said:
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

/**
 * Handles the click on the "Edit" button.  
 * Just switches the attribute around, the actual
 * edit form is added through HTML.
 * @param {Event} event Click event
 */
Comment.toggle_edit = function (event) {
  event.preventDefault();
  const parent = $(event.target).parents("article.comment");
  parent.attr("is-editing", !(parent.attr("is-editing") == "true"))
}

/**
 * Handles the click on the "Delete" button.
 * Not to be confused with `Comment.destroy`, which
 * permanently removes the comment from the database.
 * @param {Event} event Click event
 */
Comment.delete = function (event) {
  event.preventDefault();
  if (!confirm("Are you sure that you want to delete this comment?"))
    return;

  const parent = $(event.target).parents("article.comment");
  const cid = parent.data("comment-id");
  $.ajax({
    url: `/comments/${cid}/hide.json`,
    type: "POST",
    dataType: "json"
  }).done(() => {
    parent.attr("data-is-deleted", true);
  }).fail(() => {
    Utility.error("Failed to delete the comment.");
  });
};

/**
 * Handles the click on the "Undelete" button.
 * @param {Event} event Click event
 */
Comment.undelete = function (event) {
  event.preventDefault();
  if (!confirm("Are you sure that you want to undelete this comment?"))
    return;

  const parent = $(event.target).parents("article.comment");
  const cid = parent.data("comment-id");
  $.ajax({
    url: `/comments/${cid}/unhide.json`,
    type: "POST",
    dataType: "json"
  }).done(() => {
    parent.attr("data-is-deleted", false);
  }).fail(() => {
    Utility.error("Failed to undelete the comment.");
  });
};

/**
 * Handles the click on the "Mark" button.  
 * Just toggles the attribute to show the menu.
 * Actual marking is handled elsewhere.
 * @param {Event} event Click event
 */
Comment.toggle_mark = function (event) {
  event.preventDefault();
  const parent = $(event.target).parents("article.comment");
  parent.attr("is-marking", !(parent.attr("is-marking") == "true"))
};

/**
 * Handles the click on the "Destroy" button.  
 * Note that this action is permanent and irreversible.
 * @param {Event} event Click event
 */
Comment.destroy = function (event) {
  event.preventDefault();
  if (!confirm("Are you sure that you want to permanently destroy this comment?"))
    return;

  const parent = $(event.target).parents("article.comment");
  const cid = parent.data("comment-id");
  $.ajax({
    url: `/comments/${cid}.json`,
    type: "DELETE",
    dataType: "json"
  }).done(() => {
    parent.remove();
  }).fail(() => {
    Utility.error("Failed to destroy the comment.");
  });
};

/**
 * Handles the click on the "Show all comments" button.  
 * Due to the way comments get loaded, all handlers will be
 * reinitializes as a result, otherwise buttons won't work.
 * @param {Event} event Click event
 */
Comment.show_all = function (event) {
  event.preventDefault();
  const target = $(event.target);
  const post_id = target.data("pid");
  $.ajax({
    url: `/posts/${post_id}/comments.json`,
    type: "GET",
    dataType: "json"
  }).done(function (data) {
    $(`#threshold-comments-notice-for-${post_id}`).hide();

    $(`div.comments-for-post[data-post-id=${post_id}] div.comments-list`).html(data.html);
    Comment.reinitialize_all();
    UserWarnable.reinitialize_click_handlers();
    $(window).trigger("e621:add_deferred_posts", data.posts);
  }).fail(function (data) {
    Utility.error("Failed to fetch all comments for this post.");
  });
};



$(() => {
  Comment.initialize_all();
});

export default Comment
