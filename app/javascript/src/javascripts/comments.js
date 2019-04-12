let Comment = {};

Comment.initialize_all = function () {
  if ($("#c-posts").length || $("#c-comments").length) {
    $(document).on("click.danbooru.comment", ".edit_comment_link", Comment.show_edit_form);
    $(document).on("click.danbooru.comment", ".expand-comment-response", Comment.show_new_comment_form);
    $(document).on("click.danbooru.comment", '.comment-vote-up-link', Comment.vote_up);
    $(document).on("click.danbooru.comment", ".comment-vote-down-link", Comment.vote_down);
  }
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
