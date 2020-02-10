import Utility from "./utility";

let Comment = {};

Comment.initialize_all = function () {
  if ($("#c-posts").length || $("#c-comments").length) {
    $(document).on("click.danbooru.comment", ".edit_comment_link", Comment.show_edit_form);
    $(document).on("click.danbooru.comment", ".expand-comment-response", Comment.show_new_comment_form);
    $(document).on("click.danbooru.comment", '.comment-vote-up-link', Comment.vote_up);
    $(document).on("click.danbooru.comment", ".comment-vote-down-link", Comment.vote_down);
    $(".comment-reply-link").on('click', Comment.quote);
    $(".comment-hide-link").on('click', Comment.hide);
    $(".comment-unhide-link").on('click', Comment.unhide);
    $(".comment-delete-link").on('click', Comment.delete);
    $(".comment-tag-hide-link").on("click", Comment.toggle_post_tags)
  }
}

Comment.hide = function (e) {
  e.preventDefault();
  if (!confirm("Are you sure you want to hide this comment?"))
    return;
  const parent = $(e.target).parents('article.comment');
  const cid = parent.data('comment-id');
  $.ajax({
    url: `/comments/${cid}/hide.json`,
    type: 'POST',
    dataType: 'json'
  }).done(function (data) {
    $(`.comment[data-comment-id="${cid}"] div.author h1`).append(" (hidden)");
    $(`.comment[data-comment-id="${cid}"]`).attr('data-is-deleted', 'true');
  }).fail(function (data) {
    Utility.error("Failed to hide comment.");
  });
};

Comment.unhide = function (e) {
  e.preventDefault();
  if (!confirm("Are you sure you want to unhide this comment?"))
    return;
  const parent = $(e.target).parents('article.comment');
  const cid = parent.data('comment-id');
  $.ajax({
    url: `/comments/${cid}/unhide.json`,
    type: 'POST',
    dataType: 'json'
  }).done(function (data) {
    const $author = $(`.comment[data-comment-id="${cid}"] div.author h1`);
    $author.text($author.text().replace(" (hidden)", ""));
    $(`.comment[data-comment-id="${cid}"]`).attr('data-is-deleted', 'false');
  }).fail(function (data) {
    Utility.error("Failed to unhide comment.");
  });
};

Comment.delete = function (e) {
  e.preventDefault();
  if (!confirm("Are you sure you want to permanently delete this comment?"))
    return;
  const parent = $(e.target).parents('article.comment');
  const cid = parent.data('comment-id');
  $.ajax({
    url: `/comments/${cid}.json`,
    type: 'DELETE',
    dataType: 'json'
  }).done(function (data) {
    parent.remove();
  }).fail(function (data) {
    Utility.error("Failed to delete comment.");
  });
};

Comment.quote = function (e) {
  const parent = $(e.target).parents('article.comment');
  const pid = parent.data('post-id');
  const cid = parent.data('comment-id');
  $.ajax({
    url: `/comments/${cid}.json`,
    type: 'GET',
    dataType: 'json',
    accept: 'text/javascript'
  }).done(function (data) {
    let stripped_body = data.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\][\n\r]*/gm, "");
    stripped_body = `[quote]"${parent.data('creator')}":/user/show/${parent.data('creator-id')} said:
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
  const link = $(e.target);
  $(`#post-tags-${link.data('post-id')}`).toggleClass("hidden");
}

Comment.show_new_comment_form = function (e) {
  $(e.target).hide();
  var $form = $(e.target).closest("div.new-comment").find("form");
  $form.show();
  $form[0].scrollIntoView(false);
  e.preventDefault();
}

Comment.show_edit_form = function (e) {
  $(this).closest(".comment").find(".edit_comment").show();
  e.preventDefault();
}

Comment.vote_up = function (e) {
  var id = $(e.target).attr('data-id');
  Comment.vote(id, 1);
}

Comment.vote_down = function (e) {
  var id = $(e.target).attr('data-id');
  Comment.vote(id, -1);
}

Comment.vote = function (id, score) {
  $.ajax({
    method: 'POST',
    url: `/comments/${id}/votes`,
    data: {
      score: score
    },
    headers: {
      accept: '*/*;q=0.5,text/javascript'
    }
  }).done(function () {
    $(window).trigger('danbooru.notice', "Vote applied");
  });
}

$(document).ready(function () {
  Comment.initialize_all();
});

export default Comment
